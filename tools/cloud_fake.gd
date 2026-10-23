extends RefCounted
## In-memory stand-in for the Supabase endpoints Cloud uses (dev only, excluded from exports):
## anonymous sign-up, refresh, user, Google sign-in / manual identity linking (redirect flow),
## logout (refresh tokens rotate like Supabase's), and rpc_load / rpc_save with the same rev rules as supabase/migrations/0001_cloud_save.sql.
## `clock` is the fake server time.

const GOOGLE := "https://accounts.google.test/o/oauth2"

var clock := 2_000_000_000.0
var online := true
var users := {}       # access/refresh token -> user id
var accounts := {}    # user id -> {email, anon}
var rows := {}        # user id -> {rev, data, settings, device_id, updated_at}
var calls: Array = []
var refreshes := 0
var _n := 0


func handle(method: int, path: String, headers: PackedStringArray, body: String) -> Dictionary:
	await Engine.get_main_loop().process_frame
	calls.append(path)
	if not online:
		return {"code": 0, "body": null, "error": "network 4"}
	var b = JSON.parse_string(body) if body != "" else {}
	if method == HTTPClient.METHOD_GET and body != "":
		return {"code": 400, "body": {"message": "GET with a body"}}
	if path == "/auth/v1/signup":
		_n += 1
		var uid := "user-%04d-fake" % _n
		accounts[uid] = {"email": "", "anon": true}
		return {"code": 200, "body": _session(uid)}
	if path.begins_with("/auth/v1/token"):
		# like Supabase, a refresh token works once (rotation): a reused one is refused
		var uid = users.get("r:" + str(b.get("refresh_token", "")))
		if uid == null:
			return {"code": 400, "body": {"error": "invalid_grant", "error_description": "Invalid Refresh Token: Already Used"}}
		users.erase("r:" + str(b.refresh_token))
		refreshes += 1
		return {"code": 200, "body": _session(uid)}
	var uid = null
	for h in headers:
		if h.begins_with("Authorization: Bearer "):
			uid = users.get("a:" + h.substr(22))
	if uid == null:
		return {"code": 401, "body": {"message": "JWT expired"}}
	if path == "/auth/v1/user":
		return {"code": 200, "body": _user(uid)}
	if path.begins_with("/auth/v1/user/identities/authorize"):
		if not path.contains("provider=google") or not path.contains("redirect_to="):
			return {"code": 400, "body": {"msg": "bad link request"}}
		return {"code": 200, "body": {"url": GOOGLE + "?link=" + uid}}
	if path.begins_with("/auth/v1/logout"):
		for k in users.keys():
			if users[k] == uid:
				users.erase(k)
		return {"code": 204, "body": null}
	if path == "/rest/v1/rpc/rpc_load":
		var r = rows.get(uid)
		var save = null
		if r != null:
			save = r.duplicate(true)
		return {"code": 200, "body": {"server_time": clock, "save": save}}
	if path == "/rest/v1/rpc/rpc_save":
		var cur = rows.get(uid)
		var rev := 0 if cur == null else int(cur.rev)
		if cur != null and not b.p_force and rev != int(b.p_base_rev):
			return {"code": 200, "body": {"ok": false, "conflict": true, "rev": rev, "server_time": clock}}
		rows[uid] = {"rev": rev + 1, "data": b.p_data, "settings": b.p_settings, "device_id": b.p_device_id, "updated_at": clock}
		return {"code": 200, "body": {"ok": true, "rev": rev + 1, "server_time": clock}}
	return {"code": 404, "body": null}


func _user(uid: String) -> Dictionary:
	var a: Dictionary = accounts.get(uid, {"email": "", "anon": true})
	var provs := ["anonymous"] if a.anon else ["google"]
	return {"id": uid, "email": a.email, "is_anonymous": a.anon,
		"app_metadata": {"provider": provs[0], "providers": provs}}


func _session(uid: String) -> Dictionary:
	_n += 1
	var claims := {"sub": uid, "is_anonymous": bool(accounts.get(uid, {}).get("anon", true))}
	var a := "h.%s.s%d" % [Marshalls.utf8_to_base64(JSON.stringify(claims)).replace("+", "-").replace("/", "_").replace("=", ""), _n]
	var r := "ref%d" % _n
	users["a:" + a] = uid
	users["r:" + r] = uid
	return {"access_token": a, "refresh_token": r, "expires_in": 3600, "expires_at": clock + 3600.0, "user": _user(uid)}


func _owner_of(email: String) -> String:
	for uid in accounts:
		if not accounts[uid].anon and accounts[uid].email == email:
			return uid
	return ""


## what the page sees after Google sends the player back (the URL fragment), for the URL the game opened
func google_return(opened: String, email: String) -> String:
	var owner := _owner_of(email)
	var uid := ""
	if opened.begins_with(GOOGLE + "?link="):
		uid = opened.get_slice("link=", 1)
		if owner != "" and owner != uid:
			return "error=server_error&error_code=identity_already_exists&error_description=Identity+is+already+linked+to+another+user"
		accounts[uid] = {"email": email, "anon": false}
	elif opened.contains("/auth/v1/authorize?provider=google"):
		uid = owner
		if uid == "":
			_n += 1
			uid = "user-%04d-fake" % _n
			accounts[uid] = {"email": email, "anon": false}
	else:
		return "error=invalid_request"
	var s := _session(uid)
	return "access_token=%s&expires_at=%d&expires_in=3600&refresh_token=%s&token_type=bearer&type=signup" % [s.access_token, int(s.expires_at), s.refresh_token]


## pretend another device wrote this save
func write_from_other_device(uid: String, data: Dictionary, settings: Dictionary = {}) -> void:
	var cur = rows.get(uid)
	var rev := 0 if cur == null else int(cur.rev)
	rows[uid] = {"rev": rev + 1, "data": data, "settings": settings, "device_id": "other", "updated_at": clock}


## every access token expires (forces the refresh path)
func expire_tokens() -> void:
	for k in users.keys():
		if k.begins_with("a:"):
			users.erase(k)


## the server ends every session of this user (refresh tokens refused, e.g. session time-box)
func revoke(uid: String) -> void:
	for k in users.keys():
		if users[k] == uid:
			users.erase(k)
