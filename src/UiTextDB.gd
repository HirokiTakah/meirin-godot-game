extends Object

const UI_TEXTS_JSON_PATH := "res://data/ui_texts.json"

var _ui: Dictionary = {}


func _init() -> void:
	_load_ui_texts()


func _load_ui_texts() -> void:
	_ui.clear()

	if not ResourceLoader.exists(UI_TEXTS_JSON_PATH):
		push_warning("ui_texts.json が見つかりません: %s" % UI_TEXTS_JSON_PATH)
		return

	var file := FileAccess.open(UI_TEXTS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("ui_texts.json を開けませんでした")
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ui_texts.json の形式が不正です")
		return

	_ui = parsed


func get_move_name(index: int) -> String:
	var arr: Array = _ui.get("move_names", [])
	if index < 0 or index >= arr.size():
		return ""
	return String(arr[index])


func get_drain_start_message() -> String:
	return String(_ui.get("drain", {}).get("start_message", ""))


func get_drain_last_message() -> String:
	return String(_ui.get("drain", {}).get("last_message", ""))


func get_game_over_label() -> String:
	return String(_ui.get("game_over", {}).get("label", ""))


func get_game_over_message() -> String:
	return String(_ui.get("game_over", {}).get("message", ""))


func get_clear_label() -> String:
	return String(_ui.get("clear", {}).get("label", ""))


func get_clear_result_label() -> String:
	return String(_ui.get("clear", {}).get("result_label", ""))


func get_clear_battle_message() -> String:
	return String(_ui.get("clear", {}).get("battle_message", ""))
