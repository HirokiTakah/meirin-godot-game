extends Node

# ----------------------------------------------------------
# Meirin Battle Game - Global GameState
# 数値計算・ステージ管理専用版（テキストは BattleText に委譲）
# ----------------------------------------------------------

const STAGES_JSON_PATH := "res://data/stages.json"
const BattleText = preload("res://src/BattleText.gd")

# じゃんけん結果
const ROUND_DRAW := 0
const ROUND_WIN := 1
const ROUND_LOSE := 2

# ダメージ関連のバランス定数
const MISS_RATE := 0.10                # ミス率 10%（前は 15%）
const CRITICAL_RATE := 0.20            # クリティカル率 20%（前は 15%）
const FORM2_DAMAGE_BONUS := 1
const STAGE7_DAMAGE_BONUS := 1
const STAGE6_NO_DAMAGE_THRESHOLD := 3  # ステージ6で「効かない攻撃」の回数

# メイリン立ち絵テクスチャ
const MEIRIN_TEXTURES := {
	1: { # フェイス1
		"idle": "res://assets/sprites/face1_idle.png",
		"damage": "res://assets/sprites/face1_damage.png",
		"down": "res://assets/sprites/face1_down.png",
	},
	2: { # フェイス2（ダメージ／ダウンは共通絵）
		"idle": "res://assets/sprites/face2_idle.png",
		"damage": "res://assets/sprites/face1_damage.png",
		"down": "res://assets/sprites/face1_down.png",
	},
}

# ========================
# ゲームの状態変数
# ========================

var player_hp: int = 10
var player_max_hp: int = 10

var enemy_hp: int = 5
var enemy_max_hp: int = 5

var game_stage: int = 1
var tea_pieces: int = 0
var meirin_form: int = 1 # 1=FACE1 / 2=FACE2

var is_gameover := false

# ステージ6ボス用
var boss_no_damage_count: int = 0
var boss_hp_drain_active: bool = false

# JSON から読むステージ定義
var stage_data: Dictionary = {}


func _ready() -> void:
	load_stages()
	init_stage()


# ========================
# ステージ設定読み込み
# ========================

func load_stages() -> void:
	stage_data.clear()

	if not ResourceLoader.exists(STAGES_JSON_PATH):
		push_error("stages.json が見つかりません: %s" % STAGES_JSON_PATH)
		return

	var file := FileAccess.open(STAGES_JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("stages.json を開けませんでした")
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("stages.json の形式が不正です")
		return

	# キーを int に変換して保持
	for k in parsed.keys():
		var ik := int(k)
		stage_data[ik] = parsed[k]


func _get_stage_dict(stage: int) -> Dictionary:
	return stage_data.get(stage, {})


# =========================
# ステージ初期化
# =========================

func init_stage() -> void:
	var d := _get_stage_dict(game_stage)

	# enemyHP は JSON の "enemyHP" に合わせる
	var enemy_hp_val: int = int(d.get("enemyHP", 5))
	enemy_max_hp = enemy_hp_val
	enemy_hp = enemy_max_hp

	# プレイヤーHPはステージ開始ごとに全回復
	player_hp = player_max_hp

	# ステージ6以外ではボス用カウンタをリセット
	if game_stage != 6:
		boss_no_damage_count = 0
		boss_hp_drain_active = false

	is_gameover = false

	# ティーピースが4つ以上ならフォーム2
	if tea_pieces >= 4:
		meirin_form = 2

	print("ステージ開始:", game_stage, " enemyHP:", enemy_max_hp, " playerHP:", player_hp)


# =========================
# ステージ導入文
# =========================

func get_stage_intro_message() -> String:
	return BattleText.get_stage_intro(game_stage)


# =========================
# 背景画像パス
# =========================

func get_stage_background_path() -> String:
	var d := _get_stage_dict(game_stage)
	var bg_name: String = String(d.get("background", ""))

	if bg_name == "":
		return ""

	# 例: res://assets/backgrounds/market.png
	return "res://assets/backgrounds/%s.png" % bg_name


# =========================
# メイリン立ち絵テクスチャ
# =========================

func get_meirin_texture_path(state: String = "idle") -> String:
	var form_dict: Dictionary = MEIRIN_TEXTURES.get(meirin_form, {})
	if form_dict.is_empty():
		return ""
	return String(form_dict.get(state, form_dict.get("idle", "")))


# =========================
# HPを全回復（Continue 用）
# =========================

func restore_full_hp() -> void:
	player_hp = player_max_hp
	enemy_hp = enemy_max_hp


# ============================================================
# じゃんけんロジック（数値計算＋フラグ生成のみ）
# ============================================================

func player_attack(player_choice: int) -> Dictionary:
	if is_gameover:
		return {"result": "gameover"}

	if player_hp <= 0 or enemy_hp <= 0:
		return {"result": "ended"}

	# 敵の手
	var enemy_choice := randi() % 3
	var round_result: int = (3 + player_choice - enemy_choice) % 3

	# ここで「あいこ」を減らす工夫：
	# 一度あいこになったら、もう一度だけ敵の手を振り直して、
	# それでもあいこならそのまま。
	if round_result == ROUND_DRAW:
		var second_enemy_choice := randi() % 3
		var second_result: int = (3 + player_choice - second_enemy_choice) % 3
		if second_result != ROUND_DRAW:
			enemy_choice = second_enemy_choice
			round_result = second_result
	# この結果、あいこ率は 1/3 → 約 1/9 くらいまで減ります

	# ダメージ処理
	var damage := 0
	var miss := false
	var critical := false
	var ineffective := false
	var start_drain := false

	# -------------------------------
	# ダメージ／ミス／無効判定
	# -------------------------------
	if round_result == ROUND_WIN or round_result == ROUND_LOSE:
		# ステージ6：必殺技前はプレイヤー勝ちでもダメージ0（一定回数まで）
		if game_stage == 6 and not boss_hp_drain_active and round_result == ROUND_WIN:
			ineffective = true
			damage = 0
			boss_no_damage_count += 1

			if boss_no_damage_count >= STAGE6_NO_DAMAGE_THRESHOLD:
				# 規定回数効かない攻撃 → HPドレイン開始フラグON
				boss_hp_drain_active = true
				start_drain = true
		else:
			# 通常のランダム判定
			var roll := randf()
			if roll < MISS_RATE:
				damage = 0
				miss = true
			elif roll > 1.0 - CRITICAL_RATE:
				damage = 2
				critical = true
			else:
				damage = 1

		# フォーム2補正（プレイヤー勝ち時）
		if meirin_form == 2 and round_result == ROUND_WIN and damage > 0 and not miss and not ineffective:
			damage += FORM2_DAMAGE_BONUS

		# ステージ7補正
		if game_stage == 7 and damage > 0 and not miss and not ineffective:
			damage += STAGE7_DAMAGE_BONUS

	# -------------------------------
	# ダメージ適用
	# -------------------------------
	if round_result == ROUND_WIN and not ineffective:
		enemy_hp -= damage
	elif round_result == ROUND_LOSE:
		player_hp -= damage

	if enemy_hp < 0:
		enemy_hp = 0
	if player_hp < 0:
		player_hp = 0

	# 通常の敗北時はゲームオーバー扱い
	if player_hp <= 0 and game_stage != 6:
		is_gameover = true

	# -------------------------------
	# テキスト生成（BattleText に委譲）
	# -------------------------------
	var text_dict: Dictionary = BattleText.get_round_text(
		game_stage,
		round_result,
		miss,
		critical,
		ineffective,
		start_drain,
		player_hp,
		enemy_hp
	)

	var result_msg: String = text_dict.get("result_msg", "")
	var battle_msg: String = text_dict.get("battle_msg", "")

	return {
		"player_hp": player_hp,
		"enemy_hp": enemy_hp,
		"result_msg": result_msg,
		"battle_msg": battle_msg,
		"start_drain": start_drain,
		"round_result": round_result,
	}


# ================================
# ティーピース獲得 → 次ステージへ
# ================================

func next_stage() -> void:
	# 1〜4面クリア時にティーピース獲得
	if game_stage <= 4:
		tea_pieces += 1

	# フォーム2解放
	if tea_pieces >= 4:
		meirin_form = 2

	game_stage += 1

	# 次のステージを初期化
	init_stage()
