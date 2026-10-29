class_name LegalPolicy
extends RefCounted
## MV-589: local, versioned choices. A legacy telemetry=true preference is not consent.
const PATH := "res://config/legal_notice.json"
static var document_override: Dictionary = {} # isolated tests only; never saved
static var _document: Dictionary = {}

static func document() -> Dictionary:
	if not document_override.is_empty():
		return document_override
	if _document.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_document = parsed
	return _document

static func publication_ready() -> bool:
	var d := document()
	if d.get("status", "draft") != "published" or d.get("reviewed_for_publication", false) != true:
		return false
	for key in ["name", "email", "contact_address"]:
		if not _filled(str(d.get("controller", {}).get(key, ""))):
			return false
	for key in ["account", "diagnostics", "analytics", "backups"]:
		if not _filled(str(d.get("retention", {}).get(key, ""))):
			return false
	return _filled(str(d.get("effective_date", ""))) and _filled(str(d.get("transfer_safeguards", ""))) \
		and _filled(str(d.get("terms_version", ""))) and _filled(str(d.get("privacy_version", "")))

static func _filled(value: String) -> bool:
	return value.strip_edges() != "" and not value.contains("[") and value != "<null>"

static func receipt() -> Dictionary:
	var value = Settings.get_value("legal_consent")
	return value if value is Dictionary else {}

static func accepted() -> bool:
	var r := receipt()
	var d := document()
	if typeof(r.get("accepted_at", 0.0)) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	return publication_ready() and r.get("terms_version", "") == d.get("terms_version", "") \
		and r.get("privacy_version", "") == d.get("privacy_version", "") \
		and float(r.get("accepted_at", 0.0)) > 0.0

static func needs_acceptance() -> bool:
	return BuildInfo.env() in ["uat", "prod"] and Features.on("legal_notice") and publication_ready() and not accepted()

static func allows(purpose: String) -> bool:
	return purpose in ["diagnostics", "analytics"] and accepted() \
		and Settings.get_value("telemetry") == true and receipt().get(purpose, false) == true

static func record_choices(diagnostics: bool, analytics: bool) -> bool:
	if not publication_ready():
		return false
	var previous := receipt()
	var now := Time.get_unix_time_from_system()
	Settings.set_value("legal_consent", {"terms_version": document().terms_version,
		"privacy_version": document().privacy_version,
		"accepted_at": float(previous.accepted_at) if accepted() else now,
		"changed_at": now, "diagnostics": diagnostics, "analytics": analytics})
	Settings.set_value("telemetry", diagnostics or analytics)
	return true

static func withdraw_all() -> void:
	Settings.set_value("telemetry", false)
	var r := receipt().duplicate(true)
	if not r.is_empty():
		r.diagnostics = false
		r.analytics = false
		r.changed_at = Time.get_unix_time_from_system()
		Settings.set_value("legal_consent", r)

static func section_text(text: String) -> String:
	var d := document()
	var placeholders: Dictionary = d.get("provider_display", {})
	for key in ["name", "email", "contact_address"]:
		var value := str(d.get("controller", {}).get(key, ""))
		if _filled(value):
			text = text.replace(str(placeholders.get(key, "")), value)
	var retention: Dictionary = d.get("retention", {})
	var retention_tags := {"account": "[ระยะเวลาและเงื่อนไขเก็บข้อมูลบัญชี]",
		"diagnostics": "[ระยะเวลาเก็บและเงื่อนไขลบจริง]", "analytics": "[ระยะเวลาเก็บของบริการที่ใช้จริง]",
		"backups": "[ระยะเวลาและเงื่อนไขที่เกี่ยวข้อง]"}
	for key in retention_tags:
		if _filled(str(retention.get(key, ""))):
			text = text.replace(retention_tags[key], str(retention[key]))
	if _filled(str(d.get("transfer_safeguards", ""))):
		text = text.replace("[รายละเอียดตามการตั้งค่าบริการจริง]", str(d.transfer_safeguards))
	return text
