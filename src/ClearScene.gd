# res://src/ClearScene.gd
extends Control

@onready var retry_button: Button = $UI/Panel/RetryButton


func _ready() -> void:
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)


func _on_retry_pressed() -> void:
	# ゲーム全体を最初の状態に戻す
	GameState.reset_run()
	StoryFlowDB.reset_story()

	# 最初のイベントシーンへ
	get_tree().change_scene_to_file("res://scenes/event/EventScene.tscn")
