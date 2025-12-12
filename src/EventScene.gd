extends Control

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"

const UiText = preload("res://src/UiText.gd")

@onready var speaker_label: Label = $UI/UIRoot/SpeakerLabel
@onready var text_label: Label = $UI/UIRoot/TextLabel
@onready var next_button: Button = $UI/UIRoot/NextButton

var _lines: Array = []
var _line_index: int = 0

func _ready() -> void:
	_lines = StoryFlowDB.get_current_event_lines()
	_line_index = 0

	if next_button:
		next_button.text = UiText.text("event.buttons.next", "つぎへ")
		next_button.pressed.connect(_on_next_pressed)


	_show_current_line()


func _show_current_line() -> void:
	if _lines.is_empty():
		_go_next_node()
		return

	if _line_index < 0 or _line_index >= _lines.size():
		_go_next_node()
		return

	var line: Dictionary = _lines[_line_index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	if speaker_label:
		speaker_label.text = speaker
	if text_label:
		text_label.text = text


func _on_next_pressed() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_go_next_node()
	else:
		_show_current_line()

func _go_next_node() -> void:
	# いま表示しているイベントノード
	var node: Dictionary = StoryFlowDB.get_current_node()
	var node_id: String = String(node.get("id", ""))

	# 1) エンディングイベント（event_09_ending）のときは、
	#    次のノードには進まず、そのまま ClearScene へ遷移する。
	if node_id == "event_09_ending":
		get_tree().change_scene_to_file("res://scenes/clear/clear_scene.tscn")
		return

	# 2) それ以外のイベントは、従来どおり「次のノード」に進む
	StoryFlowDB.goto_next_node()

	# 次がバトルなら、対応するステージ番号に合わせて BattleScene へ
	if StoryFlowDB.is_current_battle():
		var battle_index: int = StoryFlowDB.get_battle_index_upto_current()
		if battle_index <= 0:
			battle_index = 1

		GameState.game_stage = battle_index
		GameState.init_stage()

		get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		return

	# 次もイベントなら、いったんシーンをリロード
	if StoryFlowDB.is_current_event():
		get_tree().reload_current_scene()
		return

	# それ以外（予期しない場合）はバトルシーンに戻すフォールバック
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
