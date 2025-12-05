# res://src/StoryDB.gd

extends Object

const BATTLE_TEXTS_JSON_PATH := "res://data/battle_texts.json"

var _stage_texts: Dictionary = {}

func _init() -> void:
	_load_battle_texts()


func _load_battle_texts() -> void:
	_stage_texts.clear()

	if not ResourceLoader.exists(BATTLE_TEXTS_JSON_PATH):
		push_warning("battle_texts.json が見つかりません: %s" % BATTLE_TEXTS_JSON_PATH)
		return

	var file := FileAccess.open(BATTLE_TEXTS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("battle_texts.json を開けませんでした")
		return

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("battle_texts.json の形式が不正です")
		return

	_stage_texts = parsed


func get_stage_intro(stage: int) -> String:
	var key := str(stage)

	if _stage_texts.has(key):
		return String(_stage_texts[key].get("intro", ""))

	if _stage_texts.has("default"):
		return String(_stage_texts["default"].get("intro", ""))

	return ""


func get_stage_win_message(stage: int) -> String:
	var key := str(stage)

	if _stage_texts.has(key):
		return String(_stage_texts[key].get("win_message", ""))

	if _stage_texts.has("default"):
		return String(_stage_texts["default"].get("win_message", ""))

	return ""


func _get_round_dict(stage: int) -> Dictionary:
	var key := str(stage)
	var round_dict: Dictionary = {}

	# ステージ固有の round
	if _stage_texts.has(key):
		round_dict = _stage_texts[key].get("round", {})

	# なければ default.round を使う
	if round_dict.is_empty() and _stage_texts.has("default"):
		round_dict = _stage_texts["default"].get("round", {})

	return round_dict


func _pick_random_line(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return String(lines[randi() % lines.size()])


func get_round_text(
	stage: int,
	round_result: int,
	miss: bool,
	critical: bool,
	ineffective: bool,
	start_drain: bool,
	_player_hp: int,
	_enemy_hp: int
) -> Dictionary:
	var round_dict: Dictionary = _get_round_dict(stage)

	var key := ""

	# round_result: 0=あいこ, 1=勝ち, 2=負け
	if start_drain:
		key = "drain_start"
	elif ineffective:
		key = "ineffective"
	elif miss:
		key = "miss"
	elif round_result == 0:
		key = "draw"
	elif round_result == 1:
		key = "win_critical" if critical else "win_normal"
	elif round_result == 2:
		key = "lose"

	var entry: Dictionary = round_dict.get(key, {})

	var result_msg: String = String(entry.get("result", ""))
	var lines: Array = entry.get("lines", [])
	var battle_msg: String = _pick_random_line(lines)

	return {
		"result_msg": result_msg,
		"battle_msg": battle_msg,
	}
