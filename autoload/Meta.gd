extends Node
## Persistent player data (name, avatar, coins, daily tasks, market, badges, rooms).
## Port of the localStorage layer in the original HTML game.

const PATH := "user://save.json"

const MARKET := [
	{"id": "goldSteth", "label": "Gold Steth", "cost": 40, "type": "steth"},
	{"id": "mintCoat", "label": "Mint Coat", "cost": 70, "type": "coat"},
	{"id": "nightGlow", "label": "Night BG", "cost": 90, "type": "bg"},
	{"id": "sparkTrail", "label": "Spark Trail", "cost": 120, "type": "trail"},
]
const TASKS := [
	{"id": "levels5", "label": "Pass 5 levels", "target": 5, "key": "levels", "reward": 30},
	{"id": "perfect3", "label": "3 perfect landings", "target": 3, "key": "perfects", "reward": 25},
	{"id": "level7", "label": "Reach level 7", "target": 7, "key": "bestLevel", "reward": 40},
]
const BADGE_LIST := ["First Shift", "Night Survivor", "Perfect 10", "Level 20 Doctor"]
const AVATARS := ["maleDoctor", "femaleDoctor", "maleNurse", "femaleNurse"]

var player_name := ""
var avatar := "maleDoctor"
var sound_on := true
var hi := 0
var coins := 0
var owned := {}
var active_item := {"steth": "default", "coat": "default", "bg": "default", "trail": "default"}
var daily := {}
var badges := {}
var rooms: Array = []
var current_room := ""
var session_id := ""


func _ready() -> void:
	randomize()
	_reset_daily_struct()
	load_save()
	if session_id == "":
		session_id = "%d-%d" % [Time.get_unix_time_from_system(), randi()]
		save()
	reset_daily_if_needed()


func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func _reset_daily_struct() -> void:
	daily = {"date": today_key(), "levels": 0, "perfects": 0, "bestLevel": 1, "claimed": {}}


func reset_daily_if_needed() -> void:
	if String(daily.get("date", "")) != today_key():
		_reset_daily_struct()
		save()


func load_save() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	player_name = String(data.get("name", ""))
	avatar = String(data.get("avatar", "maleDoctor"))
	if not AVATARS.has(avatar):
		avatar = "maleDoctor"
	sound_on = bool(data.get("sound_on", true))
	hi = int(data.get("hi", 0))
	coins = int(data.get("coins", 0))
	if typeof(data.get("owned")) == TYPE_DICTIONARY:
		owned = data["owned"]
	if typeof(data.get("active_item")) == TYPE_DICTIONARY:
		for k in active_item.keys():
			active_item[k] = String(data["active_item"].get(k, "default"))
	if typeof(data.get("daily")) == TYPE_DICTIONARY:
		daily = data["daily"]
		if typeof(daily.get("claimed")) != TYPE_DICTIONARY:
			daily["claimed"] = {}
	if typeof(data.get("badges")) == TYPE_DICTIONARY:
		badges = data["badges"]
	if typeof(data.get("rooms")) == TYPE_ARRAY:
		rooms = data["rooms"]
	current_room = clean_room(String(data.get("room", "")))
	session_id = String(data.get("session_id", ""))


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"name": player_name, "avatar": avatar, "sound_on": sound_on, "hi": hi,
		"coins": coins, "owned": owned, "active_item": active_item, "daily": daily,
		"badges": badges, "rooms": rooms, "room": current_room, "session_id": session_id,
	}))


func save_hi(score: int) -> void:
	if score > hi:
		hi = score
		save()


func add_coins(n: int) -> void:
	coins += n
	save()


func is_admin(n: String = player_name) -> bool:
	return n.strip_edges().to_lower() == "pol25"


func buy_item(id: String) -> void:
	var item := {}
	for m in MARKET:
		if m["id"] == id:
			item = m
	if item.is_empty():
		return
	if not owned.get(id, false):
		if coins < int(item["cost"]):
			return
		coins -= int(item["cost"])
		owned[id] = true
	var t: String = item["type"]
	active_item[t] = "default" if active_item.get(t, "default") == id else id
	save()


func task_progress(t: Dictionary) -> int:
	return mini(int(t["target"]), int(daily.get(t["key"], 0)))


func claim_task(id: String) -> void:
	reset_daily_if_needed()
	for t in TASKS:
		if t["id"] == id:
			if daily["claimed"].get(id, false) or task_progress(t) < int(t["target"]):
				return
			daily["claimed"][id] = true
			add_coins(int(t["reward"]))
			return


func unlock_badge(id: String) -> void:
	if not badges.get(id, false):
		badges[id] = true
		save()


# --- Rooms ---

func clean_room(code: String) -> String:
	var out := ""
	for c in code.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			out += c
	return out.substr(0, 10)


func room_name(code: String) -> String:
	for r in rooms:
		if r.get("code", "") == code:
			return String(r.get("name", code))
	return code


func remember_room(code: String, rname: String) -> void:
	code = clean_room(code)
	if code == "":
		return
	if rname.strip_edges() == "":
		rname = code
	rname = rname.strip_edges().substr(0, 22)
	var kept: Array = []
	for r in rooms:
		if r.get("code", "") != code:
			kept.append(r)
	kept.push_front({"code": code, "name": rname, "lastSeen": Time.get_unix_time_from_system()})
	rooms = kept.slice(0, 8)
	save()


func set_room(code: String) -> void:
	current_room = clean_room(code)
	save()
