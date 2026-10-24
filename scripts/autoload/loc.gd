extends Node
## Languages (MV-151). Thai is the source language: the Thai text in the code is the translation key, so
## anything not translated yet simply stays Thai. English lives in res://i18n/en.json ({"<thai>": "<english>"},
## empty = not translated yet), loaded into a Translation and switched with TranslationServer.set_locale.
##  * Labels / Buttons whose text is exactly a key are translated by Godot itself (auto_translate_mode) and follow
##    a language change on their own
##  * text built in code: Loc.t("... %d ...") % n, i.e. translate the template, then fill it (works in static
##    functions too, where Object.tr() is not available)
## tools/i18n.py wraps / extracts / checks the strings; Settings "lang" picks the language, switch "english".

signal changed

const EN_PATH := "res://i18n/en.json"

var translation: Translation
var missing := 0          # keys in en.json without English yet


func _ready() -> void:
	_load_en()
	apply()
	Settings.changed.connect(func(k): if k == "lang": apply())
	Features.changed.connect(apply)


func _load_en() -> void:
	translation = Translation.new()
	translation.locale = "en"
	if FileAccess.file_exists(EN_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(EN_PATH))
		if d is Dictionary:
			for k in d:
				if str(d[k]) == "":
					missing += 1
				elif str(k).begins_with("@") and str(k).contains(":"):
					# "@slot:ว่าง" = the same Thai word with another meaning, asked for with Loc.t("ว่าง", "slot")
					var c := str(k).find(":")
					translation.add_message(str(k).substr(c + 1), str(d[k]), str(k).substr(1, c - 1))
				else:
					translation.add_message(str(k), str(d[k]))
	TranslationServer.add_translation(translation)


## the language in use: the setting, but English only while the switch allows it
func lang() -> String:
	var l := str(Settings.get_value("lang"))
	return "en" if l == "en" and Features.on("english") else "th"


func apply() -> void:
	var l := lang()
	if TranslationServer.get_locale() != l:
		TranslationServer.set_locale(l)
		changed.emit()


## the current language's text for a Thai source string (unchanged when there is no translation). ctx tells apart
## one Thai word with two meanings (เปิด = On / Open): en.json key "@<ctx>:<thai>"
func t(s: String, ctx: String = "") -> String:
	return String(TranslationServer.translate(s, ctx))
