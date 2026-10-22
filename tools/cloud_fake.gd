extends RefCounted
## In-memory stand-in for the Supabase endpoints Cloud uses (dev only, excluded from exports):
## anonymous sign-up, refresh, rpc_load and rpc_save with the same rev rules as
## supabase/migrations/0001_cloud_save.sql. `clock` is the fake server time.

var clock := 2_000_000_000.0
var online := true
var users := {}       # access/refresh token -> user id
var rows := {}        # user id -> {rev, data, settings, device_id, updated_at}
var calls: Array = []
var _n := 0


func handle(_method: int, path: String, headers: PackedStringArray, body: String) -> Dictionary:
	await Engine.get_main_loop().process_frame
	calls.append(path)
	if not online:
		return {"code": 0, "body": null, "error": "network 4"}
	var b = JSON.parse_string(body)
	if path == "/auth/v1/signup":
		_n += 1
		var uid := "user-%04d-fake" % _n
		return {"code": 200, "body": _session(uid)}
	if path.begins_with("/auth/v1/token"):
		var uid = users.get("r:" + str(b.get("refresh_token", "")))
		if uid == null:
			return {"code": 400, "body": {"error": "invalid_grant"}}
		return {"code": 200, "body": _session(uid)}
	var uid = null
	for h in headers:
		if h.begins_with("Authorization: Bearer "):
			uid = users.get("a:" + h.substr(22))
	if uid == null:
		return {"code": 401, "body": {"message": "JWT expired"}}
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


func _session(uid: String) -> Dictionary:
	_n += 1
	var a := "acc%d" % _n
	var r := "ref%d" % _n
	users["a:" + a] = uid
	users["r:" + r] = uid
	return {"access_token": a, "refresh_token": r, "expires_in": 3600, "expires_at": clock + 3600.0, "user": {"id": uid}}


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
