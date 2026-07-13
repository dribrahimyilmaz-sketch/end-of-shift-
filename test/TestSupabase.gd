extends Node
## End-to-end Supabase test after RLS setup.
## Uses a low score (<100) so the nightly cleanup removes the test rows in 5 days.

func _ready() -> void:
	_run()


func _run() -> void:
	var ok := true

	# 1) Legit global score insert
	var saved: bool = await SB.save_score("TestBot", 55, 2, "")
	print("[SB] global save (55): ", "OK" if saved else "FAIL")
	ok = ok and saved

	# 2) Legit room score insert + room leaderboard readback
	var room := "SHIFTTEST"
	var saved_room: bool = await SB.save_score("TestBot", 56, 2, room)
	var rows: Array = await SB.get_leaderboard(room)
	var found := false
	for r in rows:
		if String(r.get("name", "")) == "TestBot" and int(r.get("score", 0)) == 56:
			found = true
	print("[SB] room save + room leaderboard: ", "OK" if saved_room and found else "FAIL", " rows=", rows.size())
	ok = ok and saved_room and found

	# 3) Global leaderboard still works
	var glob: Array = await SB.get_leaderboard("")
	print("[SB] global leaderboard rows: ", glob.size(), " top=", (glob[0] if glob.size() > 0 else {}))
	ok = ok and glob.size() > 0

	# 4) Cheat insert must be REJECTED by RLS (bypasses client clamp on purpose)
	var r1: Array = await SB._request(HTTPClient.METHOD_POST, SB.SB_URL + "/rest/v1/scores",
		JSON.stringify({"name": "Cheater", "score": 999999, "level": 2}),
		PackedStringArray(["Prefer: return=minimal"]))
	var rejected: bool = r1[0] < 200 or r1[0] >= 300
	print("[SB] cheat score 999999 rejected: ", "OK (HTTP %d)" % r1[0] if rejected else "FAIL — accepted!")
	ok = ok and rejected

	# 5) Anonymous DELETE must not remove anything
	await SB._request(HTTPClient.METHOD_DELETE, SB.SB_URL + "/rest/v1/scores?name=eq.TestBot")
	var still: Array = await SB.get_leaderboard(room)
	var survives := false
	for r in still:
		if String(r.get("name", "")) == "TestBot":
			survives = true
	print("[SB] anon delete blocked: ", "OK" if survives else "FAIL — rows were deleted!")
	ok = ok and survives

	# 6) Presence ping without name + count readback
	SB.active_player_count = -1
	await SB.ping_active("TestBot", "test-session-123")
	print("[SB] active ping: count=", SB.active_player_count, " ", "OK" if SB.active_player_count >= 1 else "FAIL")
	ok = ok and SB.active_player_count >= 1

	print("[SB] RESULT: ", "ALL OK" if ok else "SOME FAILED")
	get_tree().quit(0 if ok else 1)
