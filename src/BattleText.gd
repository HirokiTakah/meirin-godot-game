extends Object

const StoryDB = preload("res://src/StoryDB.gd")

static var _db = StoryDB.new()


static func _ensure_db() -> void:
	if _db == null:
		_db = StoryDB.new()


static func get_stage_intro(stage: int) -> String:
	_ensure_db()
	return _db.get_stage_intro(stage)
	
	
static func get_stage_win_message(stage: int) -> String:
	_ensure_db()
	return _db.get_stage_win_message(stage)


static func get_round_text(
	stage: int,
	round_result: int,
	miss: bool,
	critical: bool,
	ineffective: bool,
	start_drain: bool,
	player_hp: int,
	enemy_hp: int
) -> Dictionary:
	_ensure_db()
	return _db.get_round_text(
		stage,
		round_result,
		miss,
		critical,
		ineffective,
		start_drain,
		player_hp,
		enemy_hp
	)
