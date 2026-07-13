extends Node
## Supabase REST client (scores, active players). Port of the fetch() calls
## in the original HTML game. Uses the public (publishable) anon key.

const SB_URL := "https://vriammjvjuyyrevbsvwf.supabase.co"
const SB_KEY := "sb_publishable_GSxI0zjTs9rYn_9LiEesPQ_ajbzbiak"

var active_player_count := -1  # -1 = unknown


func _headers(json: bool) -> PackedStringArray:
	var h := PackedStringArray([
		"apikey: %s" % SB_KEY,
		"Authorization: Bearer %s" % SB_KEY,
	])
	if json:
		h.append("Content-Type: application/json")
	return h


## Returns [status_code:int, body:String]. status 0 = request failed.
func _request(method: HTTPClient.Method, url: String, body: String = "", extra: PackedStringArray = PackedStringArray()) -> Array:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0
	var headers := _headers(body != "")
	for e in extra:
		headers.append(e)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return [0, ""]
	var res: Array = await req.request_completed
	req.queue_free()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	return [int(res[1]), text]


func save_score(pname: String, score: int, level: int, room: String) -> bool:
	if pname.strip_edges().to_lower() == "pol25":
		return false
	# Server-side RLS also enforces these limits; clamp here so a legit run never gets rejected.
	var body := {"name": pname.substr(0, 16), "score": clampi(score, 0, 5000), "level": clampi(level, 1, 99)}
	if room != "":
		body["room_code"] = room
	var r: Array = await _request(HTTPClient.METHOD_POST, SB_URL + "/rest/v1/scores",
		JSON.stringify(body), PackedStringArray(["Prefer: return=minimal"]))
	if r[0] < 200 or r[0] >= 300:
		push_warning("Score save failed: %s %s" % [r[0], r[1]])
		return false
	return true


func get_leaderboard(room: String) -> Array:
	var scope := "room_code=is.null" if room == "" else "room_code=eq." + room.uri_encode()
	var url := SB_URL + "/rest/v1/scores?select=name,score,level,room_code&" + scope + "&order=score.desc&limit=10"
	var r: Array = await _request(HTTPClient.METHOD_GET, url)
	if r[0] != 200 and room == "":
		# Fallback for a scores table without a room_code column.
		r = await _request(HTTPClient.METHOD_GET,
			SB_URL + "/rest/v1/scores?select=name,score,level&order=score.desc&limit=10")
	if r[0] != 200:
		push_warning("Leaderboard failed: %s %s" % [r[0], r[1]])
		return []
	var data = JSON.parse_string(r[1])
	if typeof(data) != TYPE_ARRAY:
		return []
	var out: Array = []
	for row in data:
		if typeof(row) == TYPE_DICTIONARY and String(row.get("name", "")).strip_edges().to_lower() != "pol25":
			out.append(row)
	return out


## Upserts our session heartbeat and refreshes active_player_count.
func ping_active(pname: String, session_id: String) -> void:
	if pname == "" or pname.strip_edges().to_lower() == "pol25":
		return
	# Data minimization: only an anonymous session id + timestamp, no player name.
	var now_iso := Time.get_datetime_string_from_system(true) + "Z"
	await _request(HTTPClient.METHOD_POST, SB_URL + "/rest/v1/active_players",
		JSON.stringify({"session_id": session_id, "last_seen": now_iso}),
		PackedStringArray(["Prefer: resolution=merge-duplicates"]))
	var cutoff := Time.get_unix_time_from_system() - 45.0
	var since := Time.get_datetime_string_from_unix_time(int(cutoff)) + "Z"
	var r: Array = await _request(HTTPClient.METHOD_GET,
		SB_URL + "/rest/v1/active_players?select=session_id,last_seen&last_seen=gt." + since.uri_encode())
	if r[0] == 200:
		var data = JSON.parse_string(r[1])
		if typeof(data) == TYPE_ARRAY:
			active_player_count = data.size()
