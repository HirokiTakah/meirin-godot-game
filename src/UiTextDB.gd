extends Object
class_name UiTextDB

const UI_TEXTS_JSON_PATH: String = "res://data/ui_texts.json"

var _ui: Dictionary = {}

func _init() -> void:
	_load_ui_texts()

func reload() -> void:
	_load_ui_texts()

func _load_ui_texts() -> void:
	_ui.clear()

	if not ResourceLoader.exists(UI_TEXTS_JSON_PATH):
		push_warning("ui_texts.json が見つかりません: %s" % UI_TEXTS_JSON_PATH)
		return

	var file: FileAccess = FileAccess.open(UI_TEXTS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("ui_texts.json を開けませんでした: %s" % UI_TEXTS_JSON_PATH)
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ui_texts.json の形式が不正です（Dictionary ではありません）: %s" % UI_TEXTS_JSON_PATH)
		return

	_ui = parsed as Dictionary

func get_text(path: String, fallback: String = "") -> String:
	var v: Variant = get_value(path, null)
	if v == null:
		return fallback
	if typeof(v) == TYPE_STRING:
		return v as String
	return str(v)

func get_value(path: String, fallback: Variant = null) -> Variant:
	if path.strip_edges() == "":
		return fallback

	var parts: PackedStringArray = path.split(".", false)
	var cur: Variant = _ui

	for i: int in range(parts.size()):
		var key: String = parts[i]
		if typeof(cur) != TYPE_DICTIONARY:
			return fallback
		var d: Dictionary = cur as Dictionary
		if not d.has(key):
			return fallback
		cur = d[key]

	return cur

# 互換API（既存コードを壊さないため残す）
func get_move_name(index: int) -> String:
	var arr_v: Variant = _ui.get("move_names", [])
	if typeof(arr_v) != TYPE_ARRAY:
		return ""
	var arr: Array = arr_v as Array
	if index < 0 or index >= arr.size():
		return ""
	return str(arr[index])

func get_drain_start_message() -> String:
	return str((_ui.get("drain", {}) as Dictionary).get("start_message", ""))

func get_drain_last_message() -> String:
	return str((_ui.get("drain", {}) as Dictionary).get("last_message", ""))

func get_game_over_label() -> String:
	return str((_ui.get("game_over", {}) as Dictionary).get("label", ""))

func get_game_over_message() -> String:
	return str((_ui.get("game_over", {}) as Dictionary).get("message", ""))

func get_clear_label() -> String:
	return str((_ui.get("clear", {}) as Dictionary).get("label", ""))

func get_clear_result_label() -> String:
	return str((_ui.get("clear", {}) as Dictionary).get("result_label", ""))

func get_clear_battle_message() -> String:
	return str((_ui.get("clear", {}) as Dictionary).get("battle_message", ""))

func get_tea_piece_reward_message() -> String:
	return str((_ui.get("reward", {}) as Dictionary).get("tea_piece", ""))

func get_form2_unlocked_message() -> String:
	return str((_ui.get("form", {}) as Dictionary).get("form2_unlocked", ""))
