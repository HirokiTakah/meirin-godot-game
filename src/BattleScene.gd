extends Node2D

const BattleFlow = preload("res://src/BattleFlow.gd")
const BattleEffects = preload("res://src/BattleEffects.gd")
const UiText = preload("res://src/UiText.gd")

# ========================================
# UIノード
# ========================================

@onready var player_hp_bar: ProgressBar = $UI/UIRoot/PlayerHPBar
@onready var enemy_hp_bar: ProgressBar = $UI/UIRoot/EnemyHPBar

@onready var result_text: Label = $UI/UIRoot/ResultLabel
@onready var battle_text: Label = $UI/UIRoot/MessagePanel/MessageLabel
@onready var message_panel: Control = $UI/UIRoot/MessagePanel

@onready var janken_buttons: Control = $UI/UIRoot/JankenButtons
@onready var btn_rock: Button = $UI/UIRoot/JankenButtons/BtnRock
@onready var btn_scissors: Button = $UI/UIRoot/JankenButtons/BtnScissors
@onready var btn_paper: Button = $UI/UIRoot/JankenButtons/BtnPaper

@onready var move_name_label: Label = $UI/UIRoot/MoveNameLabel

@onready var gameover_panel: Control = $UI/UIRoot/GameOverPanel
@onready var btn_continue: Button = $UI/UIRoot/GameOverPanel/RetryButton
@onready var gameover_label: Label = $UI/UIRoot/GameOverPanel/GameOverLabel

# 立ち絵・敵・背景
@onready var meirin_sprite: Sprite2D = $MeirinSprite
@onready var enemy_sprite: Sprite2D = $EnemySprite
@onready var bg_sprite: Sprite2D = $Background
@onready var gameover_bg_sprite: Sprite2D = $GameOverBG

# 背景テクスチャパス
const GAMEOVER_BG_PATH := "res://assets/backgrounds/game_over.png"
const CLEAR_BG_PATH := "res://assets/backgrounds/game_clear.png"

# ステージ6ドレイン用
var drain_timer: Timer
var draining: bool = false

# 1ターン処理中かどうか（ボタン連打防止）
var processing_turn: bool = false

# フェイス2導入アニメーションを再生済みかどうか
var played_form2_intro: bool = false

# 1文字ずつ表示するときの速さ
const TYPEWRITER_SPEED := 0.01


# ========================================
# Ready
# ========================================

func _ready() -> void:
	_setup_ui()
	load_background()
	update_hp_bars()

	# 立ち絵を現在フォームに合わせて初期化
	played_form2_intro = false
	update_meirin_idle()
	draining = false

	# ステージ導入テキスト（タイプライター）
	await _play_stage_intro()


# ----------------------------------------
# 初期 UI 設定
# ----------------------------------------

func _setup_ui() -> void:
	# GameOver パネルは最初非表示
	if gameover_panel:
		gameover_panel.visible = false

	# GAME OVER/CLEAR 背景も非表示
	if gameover_bg_sprite:
		gameover_bg_sprite.visible = false

	# ResultLabel は使わないので隠す
	if result_text:
		result_text.visible = false
		result_text.text = ""

	# メッセージは左揃え
	if battle_text:
		battle_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# ボタンの表示名を JSON から設定
	var name0 := UiText.get_move_name(0)
	var name1 := UiText.get_move_name(1)
	var name2 := UiText.get_move_name(2)

	if name0 == "":
		name0 = "灯籠シールド"
	if name1 == "":
		name1 = "浄化のリボン"
	if name2 == "":
		name2 = "結び封じ"

	btn_rock.text = name0
	btn_scissors.text = name1
	btn_paper.text = name2

	# 攻撃ボタン
	btn_rock.pressed.connect(func(): on_player_choice(0))
	btn_scissors.pressed.connect(func(): on_player_choice(1))
	btn_paper.pressed.connect(func(): on_player_choice(2))

	# MoveNameLabel は使わないので隠す
	if move_name_label:
		move_name_label.visible = false
		move_name_label.text = ""

	# Continue（リトライ）
	btn_continue.pressed.connect(on_continue_pressed)


# ステージ導入テキスト
func _play_stage_intro() -> void:
	set_attack_buttons_enabled(false) # 導入中はボタン押せない
	var intro_text := GameState.get_stage_intro_message()
	await MessageHelper.typewriter_show(self, battle_text, intro_text, TYPEWRITER_SPEED)
	set_attack_buttons_enabled(true)


# ========================================
# 通常背景読み込み
# ========================================

func load_background() -> void:
	var path := GameState.get_stage_background_path()
	print("load_background:", path)

	if path == "":
		bg_sprite.texture = null
		return

	var tex: Texture2D = load(path)
	if tex:
		bg_sprite.texture = tex
	else:
		push_warning("背景画像が見つかりません: %s" % path)


# GAME OVER 用背景
func show_gameover_background() -> void:
	_show_end_background(GAMEOVER_BG_PATH)


# CLEAR 用背景
func show_clear_background() -> void:
	_show_end_background(CLEAR_BG_PATH)


func _show_end_background(path: String) -> void:
	if not gameover_bg_sprite:
		return

	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			gameover_bg_sprite.texture = tex
			gameover_bg_sprite.scale = Vector2(1.2, 1.2)
			gameover_bg_sprite.visible = true


# GAME OVER / CLEAR 時のUIマスク
func apply_end_ui_mask(alpha: float = 0.4, hide_message: bool = true) -> void:
	set_attack_buttons_enabled(false)

	if janken_buttons:
		janken_buttons.visible = false

	player_hp_bar.visible = false
	enemy_hp_bar.visible = false
	result_text.visible = false

	if message_panel and hide_message:
		message_panel.visible = false

	if gameover_panel:
		var c := gameover_panel.self_modulate
		c.a = alpha
		gameover_panel.self_modulate = c


# ========================================
# HPバー更新
# ========================================

func update_hp_bars() -> void:
	player_hp_bar.max_value = GameState.player_max_hp
	player_hp_bar.value = GameState.player_hp

	enemy_hp_bar.max_value = GameState.enemy_max_hp
	enemy_hp_bar.value = GameState.enemy_hp


# ========================================
# メイリン立ち絵
# ========================================

func update_meirin_idle() -> void:
	var path := GameState.get_meirin_texture_path("idle")
	if ResourceLoader.exists(path):
		meirin_sprite.texture = load(path)

	if GameState.meirin_form == 2 and not played_form2_intro:
		played_form2_intro = true
		play_form2_intro_animation()


func show_meirin_down() -> void:
	var path := GameState.get_meirin_texture_path("down")
	if ResourceLoader.exists(path):
		meirin_sprite.texture = load(path)


func show_meirin_damage() -> void:
	var path := GameState.get_meirin_texture_path("damage")
	if ResourceLoader.exists(path):
		meirin_sprite.texture = load(path)


# ----------------------------------------
# ダウン演出
# ----------------------------------------

func play_defeat_sequence() -> void:
	# 1) ダメージ演出＋ダメージ絵
	await BattleEffects.play_player_hit_fx(meirin_sprite)

	# 2) ダウン絵
	show_meirin_down()
	await get_tree().create_timer(1.2).timeout

	if gameover_label:
		var label_text := UiText.get_game_over_label()
		if label_text == "":
			label_text = "GAME OVER"
		gameover_label.text = label_text

	show_gameover_background()
	apply_end_ui_mask(0.4, true)

	if gameover_panel:
		gameover_panel.visible = true


# ========================================
# クリア演出（最終戦勝利時）
# ========================================

func play_clear_sequence() -> void:
	if gameover_label:
		var label_text := UiText.get_clear_label()
		if label_text == "":
			label_text = "GAME CLEAR"
		gameover_label.text = label_text

	if result_text:
		var result_label := UiText.get_clear_result_label()
		if result_label == "":
			result_label = "クリア！"
		result_text.text = result_label

	if battle_text:
		var clear_msg := UiText.get_clear_battle_message()
		if clear_msg == "":
			clear_msg = "「……終わった。\n 光が、ぜんぶ戻ってきたね。」"
		battle_text.text = clear_msg

	await get_tree().create_timer(1.0).timeout

	show_clear_background()
	apply_end_ui_mask(0.2, true)

	if gameover_panel:
		gameover_panel.visible = true


# ========================================
# フェイス2 アニメーション（登場時のみ）
# ========================================

func play_form2_intro_animation() -> void:
	if GameState.meirin_form != 2:
		return

	var tex1: Texture2D = load("res://assets/sprites/face2_idle.png")
	var tex2: Texture2D = load("res://assets/sprites/face2_idle_alt.png")

	meirin_sprite.texture = tex1
	await get_tree().create_timer(0.5).timeout

	meirin_sprite.texture = tex2
	await get_tree().create_timer(0.5).timeout

	meirin_sprite.texture = tex1


# ========================================
# ステージ6ドレイン開始
# ========================================

func start_stage6_drain() -> void:
	if draining:
		return

	draining = true
	set_attack_buttons_enabled(false)

	drain_timer = Timer.new()
	drain_timer.wait_time = 1.5
	drain_timer.one_shot = false
	drain_timer.timeout.connect(_on_drain_tick)
	add_child(drain_timer)
	drain_timer.start()

	var msg := UiText.get_drain_start_message()
	if msg == "":
		msg = "……力が吸い取られていく……！"
	battle_text.text = msg


func _on_drain_tick() -> void:
	GameState.player_hp -= 1
	if GameState.player_hp < 0:
		GameState.player_hp = 0

	update_hp_bars()

	# ドレイン中も軽くダメージ演出
	await BattleEffects.play_player_hit_fx(meirin_sprite)

	if GameState.player_hp <= 0:
		drain_timer.stop()
		show_meirin_down()

		var msg := UiText.get_drain_last_message()
		if msg == "":
			msg = "……もう…動けない……。"
		battle_text.text = msg

		await get_tree().create_timer(1.5).timeout

		GameState.game_stage = 7
		GameState.init_stage()
		get_tree().reload_current_scene()
		return

	if GameState.player_hp > 0 and draining:
		update_meirin_idle()


func set_attack_buttons_enabled(enable: bool) -> void:
	btn_rock.disabled = not enable
	btn_scissors.disabled = not enable
	btn_paper.disabled = not enable


# ========================================
# ラウンド結果＋セリフのテキストを組み立てる
# ========================================

func _make_round_text(result_msg: String, battle_msg: String) -> String:
	var clean_battle := battle_msg.replace("\n", " ")
	clean_battle = clean_battle.strip_edges()

	if result_msg == "" and clean_battle == "":
		return ""

	if result_msg == "":
		return clean_battle

	if clean_battle == "":
		return "▶%s" % result_msg

	# 1行目：結果 / 2行目：セリフ
	return "▶%s\n%s" % [result_msg, clean_battle]


# ドラクエ風に1文字ずつ表示する
func _typewriter_show(text: String) -> void:
	if not battle_text:
		return

	battle_text.text = ""

	for i in text.length():
		battle_text.text += text[i]
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout


# ========================================
# プレイヤー攻撃入力
# ========================================

func on_player_choice(choice: int) -> void:
	BattleFlow.process_turn(self, choice)


# ========================================
# Continue（復活／リトライ）
# ========================================

func on_continue_pressed() -> void:
	var is_clear := false
	if gameover_label:
		is_clear = gameover_label.text.begins_with("GAME CLEAR")

	if is_clear:
		# クリア後は最初から
		GameState.game_stage = 1
		GameState.tea_pieces = 0
		GameState.meirin_form = 1
		GameState.player_hp = GameState.player_max_hp
		GameState.init_stage()
		GameState.is_gameover = false
		get_tree().reload_current_scene()
		return

	# GAME OVER からのリトライの場合など
	GameState.restore_full_hp()
	GameState.is_gameover = false
	get_tree().reload_current_scene()
