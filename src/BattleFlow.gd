extends Object

const BattleEffects = preload("res://src/BattleEffects.gd")

static func process_turn(scene: Node2D, choice: int) -> void:
	# すでにターン処理中、またはドレイン中なら無視
	if scene.processing_turn:
		return
	if scene.draining:
		return

	scene.processing_turn = true
	scene.set_attack_buttons_enabled(false)

	# 1) 攻撃エフェクト（めちゃ速い踏み込み）
	await BattleEffects.play_attack_effect(scene.meirin_sprite, choice)

	# 「技名だけ」が出ている時間（今は 0.4秒キープ）
	await scene.get_tree().create_timer(0.4).timeout

	# 判定に入る前に技名を消す（今は使っていないが保険）
	if scene.move_name_label:
		scene.move_name_label.text = ""

	# その間にゲームオーバーなどになっていたら何もしない
	if GameState.is_gameover or scene.draining:
		scene.processing_turn = false
		scene.set_attack_buttons_enabled(true)
		return

	# 2) 攻撃前のHPを記録（ダメージ検出用）
	var prev_player_hp: int = GameState.player_hp
	var prev_enemy_hp: int = GameState.enemy_hp

	# 3) 本番のじゃんけん判定
	var result: Dictionary = GameState.player_attack(choice)
	scene.update_hp_bars()

	var result_msg := ""
	var battle_msg := ""

	if result.has("result_msg"):
		result_msg = String(result["result_msg"])
	if result.has("battle_msg"):
		battle_msg = String(result["battle_msg"])

	# 4) 判定直後に「ダメージを受けたか」を判定
	var was_defeated: bool = (GameState.player_hp <= 0)
	var took_damage: bool = (GameState.player_hp < prev_player_hp)
	var enemy_defeated: bool = (GameState.enemy_hp <= 0)
	var enemy_took_damage: bool = (GameState.enemy_hp < prev_enemy_hp)
	var round_result: int = result.get("round_result", -1)

	# ダメージ演出（ここで一気にやる）
	if took_damage and not scene.draining:
		# ダメージ絵に切り替え
		scene.show_meirin_damage()
		# 揺れ＋フラッシュ
		await BattleEffects.play_player_hit_fx(scene.meirin_sprite)
		# まだ生きていたら idle に戻す
		if GameState.player_hp > 0 and not GameState.is_gameover and not scene.draining:
			scene.update_meirin_idle()

	if enemy_took_damage:
		await BattleEffects.play_enemy_hit_fx(scene.enemy_sprite)

	if round_result == 0:
		await BattleEffects.play_draw_effect(scene.meirin_sprite, scene.enemy_sprite)

	# 5) 結果＋セリフをまとめて作り、タイプライター表示（高速）
	var combined_text: String = scene._make_round_text(result_msg, battle_msg)
	await scene._typewriter_show(combined_text)

	# 6) ステージ6：この攻撃でドレイン開始したか？
	var start_drain: bool = result.get("start_drain", false)

	# 7) ステージ6：ドレイン開始
	if start_drain:
		scene.processing_turn = false
		scene.start_stage6_drain()
		return

	# 8) 通常の敗北（ステージ6ドレインではない）
	if was_defeated and not scene.draining:
		await scene.play_defeat_sequence()
		scene.processing_turn = false
		return

	# 9) 勝利 → 次ステージ or クリア演出
	if enemy_defeated:
		scene.update_meirin_idle()
		await scene.get_tree().create_timer(1.0).timeout

		if GameState.game_stage == 7:
			await scene.play_clear_sequence()
		else:
			GameState.next_stage()
			scene.get_tree().reload_current_scene()

		scene.processing_turn = false
		return

	# 10) バトル続行 → ボタン再び有効化
	scene.set_attack_buttons_enabled(true)
	scene.processing_turn = false
