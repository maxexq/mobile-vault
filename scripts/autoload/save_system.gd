extends Node
## Save backend.
##  * Web export  -> browser localStorage (via JavaScriptBridge)
##  * Desktop/editor -> user://savegame.json
## The game state is a plain Dictionary serialized as JSON.

const KEY := "mobile_vault_save_v1"
const FILE_PATH := "user://savegame.json"

signal flush_requested   # emitted when the page is being hidden/closed (web)

var _local_storage: JavaScriptObject
var _js_on_hide: JavaScriptObject   # keep a reference or the callback gets freed


func _ready() -> void:
	if is_web():
		_local_storage = JavaScriptBridge.get_interface("localStorage")
		# Save when the tab is hidden / closed (mobile browsers may kill the tab without warning)
		_js_on_hide = JavaScriptBridge.create_callback(_on_page_hidden)
		var doc := JavaScriptBridge.get_interface("document")
		var win := JavaScriptBridge.get_interface("window")
		if doc:
			doc.addEventListener("visibilitychange", _js_on_hide)
		if win:
			win.addEventListener("pagehide", _js_on_hide)


func is_web() -> bool:
	return OS.has_feature("web")


func _on_page_hidden(_args: Array) -> void:
	flush_requested.emit()


func write(data: Dictionary) -> bool:
	var text := JSON.stringify(data)
	if is_web() and _local_storage:
		_local_storage.setItem(KEY, text)
		return true
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	return true


func read() -> Dictionary:
	var text := ""
	if is_web() and _local_storage:
		var v = _local_storage.getItem(KEY)
		if v != null:
			text = str(v)
	elif FileAccess.file_exists(FILE_PATH):
		text = FileAccess.get_file_as_string(FILE_PATH)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func has_save() -> bool:
	return not read().is_empty()


func wipe() -> void:
	if is_web() and _local_storage:
		_local_storage.removeItem(KEY)
	elif FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))
