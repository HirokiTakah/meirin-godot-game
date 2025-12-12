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
# ダメージ関連のバランス定数（デバッグ用・メイリン有利）
const MISS_RATE := 0.05    # ミス率 5% に減らす
const CRITICAL_RATE := 0.30 # クリティカル率 30% に上げる
const FORM2_DAMAGE_BONUS := 1
const STAGE7_DAMAGE_BONUS := 1
const STAGE6_NO_DAMAGE_THRESHOLD := 3 # ステージ6で「効かない攻撃」の回数

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
var is_cleared: bool = false   # ←追加：ゲームを全クリアしたかどうか

# ステージ6ボス用
var boss_no_damage_count: int = 0
var boss_hp_drain_active: bool = false

# JSON から読むステージ定義（1,2,3,... をキーにした Dictionary）
var stage_data: Dictionary = {}


func _ready() -> void:
	load_stages()
	init_stage()

func reset_run() -> void:
	game_stage = 1
	tea_pieces = 0
	meirin_form = 1
	is_gameover = false
	is_cleared = false
	boss_no_damage_count = 0
	boss_hp_drain_active = false
	load_stages()
	init_stage()

# 既存の _on_retry_pressed は削除（またはコメントアウト）
# func _on_retry_pressed() -> void:
#   （削除）

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

	# JSON パース（Dictionary 型を明示する）
	var parsed: Dictionary = JSON.parse_string(text)

	if parsed.is_empty():
		push_error("stages.json の JSON パースに失敗しました")
		return

	var dict: Dictionary = parsed

	# 2パターンに対応させる：
	# A) 新形式: { "meta": {...}, "order": [...], "stages": { "stg_xxx": {...} } }
	# B) 旧形式: { "1": {...}, "2": {...}, ... }
	if dict.has("stages"):
		# 新形式
		var stages_dict: Dictionary = dict.get("stages", {})
		var order_array: Array = dict.get("order", [])

		# order があればそれを優先。なければ stages_dict のキー順でソート
		if order_array.is_empty():
			order_array = stages_dict.keys()
			order_array.sort()

		var index := 1
		for stage_id in order_array:
			if stages_dict.has(stage_id):
				stage_data[index] = stages_dict[stage_id]
				index += 1
	else:
		# 旧形式（現在の stages.json はこちら）
		var keys: Array = dict.keys()
		keys.sort()
		for k in keys:
			var ik: int = int(k)
			stage_data[ik] = dict[k]




func _get_stage_dict(stage: int) -> Dictionary:
	return stage_data.get(stage, {})


# =========================
# ステージ初期化
# =========================

func init_stage() -> void:
	var d := _get_stage_dict(game_stage)

	# enemy_hp は新旧どちらにも対応：
	# 新: "enemy_hp"
	# 旧: "enemyHP"（旧コメントとの互換用）
	var enemy_hp_val: int = int(d.get("enemy_hp", d.get("enemyHP", 5)))
	enemy_max_hp = enemy_hp_val
	enemy_hp = enemy_max_hp

	# プレイヤーHPはステージ開始ごとに全回復
	player_hp = player_max_hp

	# ステージ6以外ではボス用カウンタをリセット
	if game_stage != 6:
		boss_no_damage_count = 0
		boss_hp_drain_active = false

	is_gameover = false
	is_cleared = false    # ←追加

	# ティーピースが4つ以上ならフォーム2
	if tea_pieces >= 4:
		meirin_form = 2

	print("ステージ開始:", game_stage, " enemyHP:", enemy_max_hp, " playerHP:", player_hp)


# =========================
# ステージ導入文
# =========================

func get_stage_intro_message() -> String:
	return BattleText.get_stage_intro(game_stage)


func get_stage_win_message() -> String:
	return BattleText.get_stage_win_message(game_stage)


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

	# あいこ軽減のための振り直し
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
	# ダメージ適用（デバッグ用にメイリン有利）
	# -------------------------------
	if round_result == ROUND_WIN and not ineffective:
		# プレイヤーが勝った時は敵へのダメージを 2 倍
		enemy_hp -= damage * 2
	elif round_result == ROUND_LOSE:
		# プレイヤーが負けた時は被ダメージを 1/2（端数切り上げ）
		var dmg_to_player: int = int(ceil(float(damage) * 0.5))
		player_hp -= dmg_to_player

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

# next_stage は「報酬だけ」に変更（stage を進めない）
func next_stage() -> Dictionary:
	var d: Dictionary = _get_stage_dict(game_stage)
	var reward: Dictionary = d.get("reward", {})
	var tea_add: int = 0

	if typeof(reward) == TYPE_DICTIONARY:
		tea_add = int(reward.get("tea_piece", reward.get("tea_pieces", 0)))

	if tea_add > 0:
		tea_pieces += tea_add

	var unlocked_form2: bool = false
	if tea_pieces >= 4 and meirin_form < 2:
		meirin_form = 2
		unlocked_form2 = true

	# ここで game_stage += 1 と init_stage() はしない
	return {
		"tea_piece_add": tea_add,
		"unlocked_form2": unlocked_form2,
	}
