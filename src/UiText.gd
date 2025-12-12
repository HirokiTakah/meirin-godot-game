extends Object
class_name UiText

const UiTextDBScript := preload("res://src/UiTextDB.gd")

static var _db: UiTextDB = null

static func _ensure_db() -> void:
	if _db == null:
		_db = UiTextDBScript.new() as UiTextDB

static func reload() -> void:
	_ensure_db()
	_db.reload()

# 新API：ドットパスで文字列取得（get は使わない）
static func text(path: String, fallback: String = "") -> String:
	_ensure_db()
	return _db.get_text(path, fallback)

# 互換API：既存コードを壊さないため残す
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

static func get_tea_piece_reward_message() -> String:
	_ensure_db()
	return _db.get_tea_piece_reward_message()

static func get_form2_unlocked_message() -> String:
	_ensure_db()
	return _db.get_form2_unlocked_message()
