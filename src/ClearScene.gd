# res://src/ClearScene.gd
extends Control

@onready var retry_button: Button = $UI/Panel/RetryButton


func _ready() -> void:
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)


func _on_retry_pressed() -> void:
	# ゲーム全体を最初の状態に戻す
	GameState.game_stage = 1
	GameState.tea_pieces = 0

	GameState.player_hp = GameState.MAX_PLAYER_HP
	GameState.enemy_hp = GameState.MAX_ENEMY_HP

	GameState.is_cleared = false
	GameState.is_gameover = false

	StoryFlowDB.reset_story()
	GameState.init_stage()

	# 最初のイベントシーンへ
	get_tree().change_scene_to_file("res://scenes/event/EventScene.tscn")
