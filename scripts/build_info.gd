class_name BuildInfo
extends RefCounted
## One place for every version string the game shows (title screen, Settings > About, trace log).
## GAME_VERSION is bumped by hand per release. The build stamp (git commit, branch, time) is written
## to res://build_info.json by tools/stamp_build.sh right before a web export; a plain checkout has
## no stamp and reports itself as a "dev" build.

const GAME_NAME := "Apocarlypse: Mobile Vault"   # player-facing title; the repo, domain and save keys keep "mobile-vault"
const GAME_VERSION := "4.6"
const CODENAME := "MAMMOTH-7"
const STAMP_PATH := "res://build_info.json"

static var _stamp := {}


## {commit, branch, built (ISO UTC), dirty} or the dev fallback
static func stamp() -> Dictionary:
	if _stamp.is_empty():
		_stamp = {"commit": "dev", "branch": "", "built": "", "dirty": false}
		if FileAccess.file_exists(STAMP_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(STAMP_PATH))
			if d is Dictionary:
				_stamp.merge(d, true)
	return _stamp


static func commit_short() -> String:
	var c := str(stamp().commit)
	return c.substr(0, 7) + ("*" if bool(stamp().dirty) else "")


## "4.7.2-stable"
static func godot_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d-%s" % [int(v.major), int(v.minor), int(v.patch), str(v.status)]


static func godot_hash() -> String:
	return str(Engine.get_version_info().get("hash", "")).substr(0, 9)


## "v4.3 · GODOT 4.7.2 · 1a2b3c4" (short line under the title menu)
static func short_line() -> String:
	var v := Engine.get_version_info()
	return "v%s · GODOT %d.%d.%d · %s" % [GAME_VERSION, int(v.major), int(v.minor), int(v.patch), commit_short().to_upper()]


static func channel() -> String:
	return "debug" if OS.is_debug_build() else "release"


## browser user agent on web, "" elsewhere
static func user_agent() -> String:
	if not OS.has_feature("web"):
		return ""
	var ua = JavaScriptBridge.eval("navigator.userAgent", true)
	return str(ua) if ua != null else ""


## every row shown in Settings > About, also copied as text for bug reports
static func rows() -> Array:
	var st := stamp()
	var out := [
		["GAME", "%s v%s" % [GAME_NAME, GAME_VERSION]],
		["BUILD", "%s · %s" % [commit_short(), channel()]],
	]
	if str(st.branch) != "":
		out.append(["BRANCH", str(st.branch)])
	out.append(["BUILT", str(st.built) if str(st.built) != "" else "-"])
	out.append(["ENGINE", "Godot %s (%s)" % [godot_version(), godot_hash()]])
	out.append(["RENDER", "%s · %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_api_version()]])
	out.append(["GPU", RenderingServer.get_video_adapter_name()])
	out.append(["PLATFORM", OS.get_name() + (" (web)" if OS.has_feature("web") else "")])
	var ws := DisplayServer.window_get_size()
	out.append(["SCREEN", "%dx%d" % [ws.x, ws.y]])
	out.append(["LOCALE", OS.get_locale()])
	return out


static func as_text(extra: Array = []) -> String:
	var lines := []
	for r in rows() + extra:
		lines.append("%s: %s" % [r[0], r[1]])
	var ua := user_agent()
	if ua != "":
		lines.append("UA: " + ua)
	return "\n".join(lines)
