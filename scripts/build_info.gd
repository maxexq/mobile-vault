class_name BuildInfo
extends RefCounted
## One place for every version string the game shows (title screen, Settings > About, trace log).
## GAME_VERSION is semver (MAJOR.MINOR.PATCH[-alpha.N|-beta.N|-rc.N], MV-111); its pre-release tag is the
## release channel shown in game. Bump it with tools/release.py, which also updates the web shell and
## CHANGELOG.md; a v<GAME_VERSION> git tag publishes the GitHub Release (.github/workflows/release.yml). The build stamp (git commit, branch, time) is written
## to res://build_info.json by tools/stamp_build.sh right before a web export; a plain checkout has
## no stamp and reports itself as a "dev" build.

const GAME_NAME := "Apocarlypse: Mobile Vault"   # player-facing title; the repo, domain and save keys keep "mobile-vault"
const GAME_VERSION := "4.7.0-alpha.1"
const CODENAME := "MAMMOTH-7"
const STAMP_PATH := "res://build_info.json"

## alpha / beta / rc / stable: [EN badge, Thai note, UIKit color name]
const CHANNELS := {
	"alpha": ["ALPHA", "รุ่นทดสอบ ระบบยังเปลี่ยนได้ เซฟอาจถูกรีเซ็ต", "red"],
	"beta": ["BETA", "รุ่นทดสอบก่อนเปิดตัว ระบบครบแล้ว กำลังเก็บบั๊ก", "yellow"],
	"rc": ["RC", "รุ่นเตรียมเปิดตัว", "blue"],
	"stable": ["", "", "green"],
}

## deploy environments (MV-112): [EN badge, Thai note, UIKit color name]. prod shows no badge
const ENV_PATH := "res://config/environments.json"
const ENVS := {
	"prod": ["", "", "green"],
	"uat": ["UAT", "เซิร์ฟเวอร์ทดสอบแบบเปิด เซฟและ log แยกจากเกมจริง", "blue"],
	"staging": ["STAGING", "เซิร์ฟเวอร์ทดสอบภายใน เซฟและ log แยกจากเกมจริง", "yellow"],
	"dev": ["DEV", "บิลด์นักพัฒนา/พรีวิว เซฟและ log แยกจากเกมจริง", "red"],
}

static var _stamp := {}
## GOD MODE preview of another channel's badge ("" = the real one), never saved
static var channel_preview := ""
static var _env := ""
static var _env_cfg := {}
## GOD MODE preview of another environment's badge ("" = the real one); never changes the servers used
static var env_preview := ""


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


## "v4.7.0-alpha.1 · GODOT 4.7.2 · 1A2B3C4" (short line under the title menu)
static func short_line() -> String:
	var v := Engine.get_version_info()
	return "v%s · GODOT %d.%d.%d · %s" % [GAME_VERSION, int(v.major), int(v.minor), int(v.patch), commit_short().to_upper()]


## debug (editor / debug export) or release export
static func build_type() -> String:
	return "debug" if OS.is_debug_build() else "release"


# ---------------------------------------------------------------- environments (MV-112)
## one build serves every environment: the page's host name decides (config/environments.json). Only the exact
## production hosts are prod; anything unknown (Vercel PR previews, desktop, the editor) is dev, so it can
## never reach the production Supabase project or remote config
static func env() -> String:
	if _env == "":
		_env = env_for_host(page_host())
	return _env


## the web page's host name; "" on desktop / in the editor
static func page_host() -> String:
	if not OS.has_feature("web"):
		return ""
	var h = JavaScriptBridge.eval("window.location.hostname", true)
	return str(h) if h != null else ""


static func env_for_host(host: String) -> String:
	var cfg := env_config()
	if host == "":
		return str(cfg.get("desktop", "dev"))
	var hosts: Dictionary = cfg.get("hosts", {})
	for pattern in hosts:
		if host.matchn(str(pattern)) and ENVS.has(str(hosts[pattern])):
			return str(hosts[pattern])
	return str(cfg.get("unknown", "dev"))


## the Supabase project section of cloud_config.json this environment uses ("prod" / "test")
static func cloud_project() -> String:
	return str(env_config().get("projects", {}).get(env(), "test"))


static func env_config() -> Dictionary:
	if _env_cfg.is_empty() and FileAccess.file_exists(ENV_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(ENV_PATH))
		if d is Dictionary:
			_env_cfg = d
	return _env_cfg


## "STAGING" / "UAT" / "DEV", "" in production (or the GOD preview)
static func env_badge() -> String:
	return str(ENVS.get(env_preview if env_preview != "" else env(), ENVS.dev)[0])


static func env_note() -> String:
	return str(ENVS.get(env_preview if env_preview != "" else env(), ENVS.dev)[1])


static func env_color() -> String:
	return str(ENVS.get(env_preview if env_preview != "" else env(), ENVS.dev)[2])


# ---------------------------------------------------------------- semver
## "4.7.0-beta.2" -> {major 4, minor 7, patch 0, pre ["beta", "2"]}; short forms like "4.6" fill in zeros
static func parse_version(v: String) -> Dictionary:
	var core := v.strip_edges().trim_prefix("v").get_slice("+", 0)
	var pre := []
	var dash := core.find("-")
	if dash >= 0:
		pre = Array(core.substr(dash + 1).split("."))
		core = core.substr(0, dash)
	var n := core.split(".")
	return {
		"major": int(n[0]) if n.size() > 0 else 0,
		"minor": int(n[1]) if n.size() > 1 else 0,
		"patch": int(n[2]) if n.size() > 2 else 0,
		"pre": pre,
	}


## semver precedence: -1 / 0 / 1. A pre-release sorts before its release (4.7.0-alpha.1 < 4.7.0),
## numeric parts compare as numbers, alpha < beta < rc by text.
static func ver_cmp(a: String, b: String) -> int:
	var x := parse_version(a)
	var y := parse_version(b)
	for k in ["major", "minor", "patch"]:
		if x[k] != y[k]:
			return -1 if x[k] < y[k] else 1
	var p: Array = x.pre
	var q: Array = y.pre
	if p.is_empty() or q.is_empty():
		return 0 if p.size() == q.size() else (1 if p.is_empty() else -1)
	for i in mini(p.size(), q.size()):
		var s: String = p[i]
		var t: String = q[i]
		if s == t:
			continue
		if s.is_valid_int() and t.is_valid_int():
			return -1 if int(s) < int(t) else 1
		if s.is_valid_int() != t.is_valid_int():
			return -1 if s.is_valid_int() else 1
		return -1 if s < t else 1
	return 0 if p.size() == q.size() else (-1 if p.size() < q.size() else 1)


## the release channel from a version's pre-release tag (or the GOD preview)
static func release_channel(v: String = "") -> String:
	if v == "" and channel_preview != "":
		return channel_preview
	var pre: Array = parse_version(GAME_VERSION if v == "" else v).pre
	if pre.is_empty():
		return "stable"
	var tag := str(pre[0]).to_lower()
	return tag if CHANNELS.has(tag) else "alpha"


## "ALPHA" / "BETA" / "RC" / "" for a stable release
static func channel_badge() -> String:
	return str(CHANNELS[release_channel()][0])


static func channel_note() -> String:
	return str(CHANNELS[release_channel()][1])


static func channel_color() -> String:
	return str(CHANNELS[release_channel()][2])


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
		["CHANNEL", (channel_badge() + " · " + channel_note()) if channel_badge() != "" else "STABLE"],
		["ENV", "%s · server %s%s" % [env().to_upper(), cloud_project(), (" · " + page_host()) if page_host() != "" else ""]],
		["BUILD", "%s · %s" % [commit_short(), build_type()]],
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
