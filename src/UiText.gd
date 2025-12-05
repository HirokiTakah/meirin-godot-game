extends Object

const UiTextDB = preload("res://src/UiTextDB.gd")

static var _db = UiTextDB.new()


static func _ensure_db() -> void:
	if _db == null:
		_db = UiTextDB.new()


static func get_move_name(index: int) -> String:
	_ensure_db()
	return _db.get_move_name(index)


static func get_drain_start_message() -> String:
	_ensure_db()
	return _db.get_drain_start_message()


static func get_drain_last_message() -> String:
	_ensure_db()
	return _db.get_drain_last_message()


static func get_game_over_label() -> String:
	_ensure_db()
	return _db.get_game_over_label()


static func get_game_over_message() -> String:
	_ensure_db()
	return _db.get_game_over_message()


static func get_clear_label() -> String:
	_ensure_db()
	return _db.get_clear_label()


static func get_clear_result_label() -> String:
	_ensure_db()
	return _db.get_clear_result_label()


static func get_clear_battle_message() -> String:
	_ensure_db()
	return _db.get_clear_battle_message()
