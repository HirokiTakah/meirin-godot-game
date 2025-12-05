extends Object

const MessageHelper = preload("res://src/MessageHelper.gd")
const BattleEffects = preload("res://src/BattleEffects.gd")
# GameState は Autoload シングルトンをそのまま使う

const TYPEWRITER_SPEED := 0.01


# 1ターン分の処理
static func process_turn(scene: Node, player_choice: int) -> void:
	# すでに処理中なら無視（連打防止）
	if scene.processing_turn:
		return

	scene.processing_turn = true
	scene.set_attack_buttons_enabled(false)

	# 数値計算は GameState（Autoload シングルトン）に任せる
	var result: Dictionary = GameState.player_attack(player_choice)

	# 想定外だが念のため
	if result.get("result", "") in ["gameover", "ended"]:
		scene.processing_turn = false
		scene.set_attack_buttons_enabled(true)
		return

	# HP バー更新
	scene.update_hp_bars()

	# テキスト生成
	var result_msg: String = result.get("result_msg", "")
	var battle_msg: String = result.get("battle_msg", "")
	var combined_text: String = scene._make_round_text(result_msg, battle_msg)

	# メッセージ表示（タイプライター）
	if combined_text != "":
		await MessageHelper.typewriter_show(scene, scene.battle_text, combined_text, TYPEWRITER_SPEED)

	# ラウンド後処理（演出＋分岐）
	await _handle_post_round(scene, result)

	scene.processing_turn = false


# ラウンド後の分岐処理・演出
static func _handle_post_round(scene: Node, result: Dictionary) -> void:
	var start_drain: bool = result.get("start_drain", false)
	var round_result: int = result.get("round_result", -1)

	# --------------------------------------------------
	# 勝ち／負けに応じたモーション
	# --------------------------------------------------

	if GameState.game_stage != 6:
		# プレイヤーが勝ったターン → メイリン前進＋敵ヒット
		if round_result == GameState.ROUND_WIN:
			await BattleEffects.play_player_attack_fx(scene.meirin_sprite)
			await BattleEffects.play_enemy_hit_fx(scene.enemy_sprite)

		# プレイヤーが負けたターン（まだHPが残っている）
		# → 敵前進＋メイリンダメージ
		elif round_result == GameState.ROUND_LOSE and GameState.player_hp > 0:
			await BattleEffects.play_enemy_attack_fx(scene.enemy_sprite)
			scene.show_meirin_damage()
			await BattleEffects.play_player_hit_fx(scene.meirin_sprite)
			scene.update_meirin_idle()

	# --------------------------------------------------
	# 特殊処理・勝敗判定
	# --------------------------------------------------

	# ステージ6：HPドレイン開始
	if GameState.game_stage == 6 and start_drain:
		scene.start_stage6_drain()
		return

	# プレイヤー敗北（ステージ6以外）
	if GameState.player_hp <= 0 and GameState.game_stage != 6:
		await scene.play_defeat_sequence()
		return

	# 敵撃破
	if GameState.enemy_hp <= 0:
		await _handle_enemy_defeated(scene)
		return

	# どちらも生きている → 次ターンへ
	scene.set_attack_buttons_enabled(true)
	scene.update_meirin_idle()


# 敵撃破時の処理（ステージ遷移／クリア）
static func _handle_enemy_defeated(scene: Node) -> void:
	# 最終ステージ以外 → 次のステージへ
	if GameState.game_stage < 7:
		GameState.next_stage()
		scene.get_tree().reload_current_scene()
		return

	# 最終ステージ → クリア演出
	await scene.play_clear_sequence()
