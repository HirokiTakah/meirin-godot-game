extends Object

# ここだけ別名で preload して使う（グローバルクラス名との衝突を避ける）
const MessageHelperScript := preload("res://src/MessageHelper.gd")
const BattleEffects := preload("res://src/BattleEffects.gd")
const UiText := preload("res://src/UiText.gd")
# GameState / StoryFlowDB は Autoload シングルトン

const TYPEWRITER_SPEED: float = 0.01


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
	var result_msg: String = String(result.get("result_msg", ""))
	var battle_msg: String = String(result.get("battle_msg", ""))
	var combined_text: String = scene._make_round_text(result_msg, battle_msg)

	# メッセージ表示（タイプライター）
	if combined_text != "":
		await MessageHelperScript.typewriter_show(
			scene,
			scene.battle_text,
			combined_text,
			TYPEWRITER_SPEED
		)

	# ラウンド後処理（演出＋分岐）
	await _handle_post_round(scene, result)

	scene.processing_turn = false


# ラウンド後の分岐処理・演出
static func _handle_post_round(scene: Node, result: Dictionary) -> void:
	var start_drain: bool = bool(result.get("start_drain", false))
	var round_result: int = int(result.get("round_result", -1))

	# --------------------------------------------------
	# 勝ち／負けに応じたモーション（ステージ6以外）
	# --------------------------------------------------

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

	# プレイヤー敗北
	if GameState.player_hp <= 0:
		# 共通の敗北演出
		await scene.play_defeat_sequence()

		# ステージ6だけは「演出上の敗北」→ 次のイベントへ進める
		if GameState.game_stage == 6:
			StoryFlowDB.debug_print_state("before goto_next_node (stage6 defeat)")
			StoryFlowDB.goto_next_node()
			StoryFlowDB.debug_print_state("after goto_next_node (stage6 defeat)")

			if StoryFlowDB.is_current_event():
				scene.get_tree().change_scene_to_file("res://scenes/event/EventScene.tscn")
				return

			# 想定外でイベントでない場合は、とりあえずバトルシーンをリロード
			scene.get_tree().reload_current_scene()
			return

		# ステージ6以外は従来どおり（ここで処理終了。GameOverパネルは BattleScene 側の演出次第）
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
	# 最終ステージ以外
	if GameState.game_stage < 7:
		scene.set_attack_buttons_enabled(false)

		# 1) ステージ勝利メッセージ
		var win_msg: String = GameState.get_stage_win_message()
		if win_msg != "":
			await MessageHelper.typewriter_show(
				scene,
				scene.battle_text,
				win_msg,
				TYPEWRITER_SPEED
			)

		await scene.get_tree().create_timer(0.8).timeout

		# 2) 報酬（茶器）
		var reward_info: Dictionary = GameState.next_stage()
		var tea_add: int = int(reward_info.get("tea_piece_add", 0))
		if tea_add > 0:
			var tea_msg: String = UiText.get_tea_piece_reward_message()
			if tea_msg != "":
				await MessageHelper.typewriter_show(
					scene,
					scene.battle_text,
					tea_msg,
					TYPEWRITER_SPEED
				)
			await scene.get_tree().create_timer(0.8).timeout

		# 3) フェイス2解放メッセージ
		var unlocked_form2: bool = bool(reward_info.get("unlocked_form2", false))
		if unlocked_form2:
			var form_msg: String = UiText.get_form2_unlocked_message()
			if form_msg != "":
				await MessageHelper.typewriter_show(
					scene,
					scene.battle_text,
					form_msg,
					TYPEWRITER_SPEED
				)
			await scene.get_tree().create_timer(0.8).timeout

		# StoryFlowDB を進めて、次がイベントなら EventScene へ
		StoryFlowDB.debug_print_state("before goto_next_node")
		StoryFlowDB.goto_next_node()
		StoryFlowDB.debug_print_state("after goto_next_node")

		if StoryFlowDB.is_current_event():
			scene.get_tree().change_scene_to_file("res://scenes/event/EventScene.tscn")
			return

		# 次もバトルならバトルシーンを再読み込み
		scene.get_tree().reload_current_scene()
		return

	# -------------------------------
	# ここから最終ステージ（7）撃破時
	# -------------------------------
	# 「ゲームクリアした」というフラグを立てる
	GameState.is_cleared = true

	# battle_06_final_boss → event_09_ending に進める
	StoryFlowDB.debug_print_state("before goto_next_node (final)")
	StoryFlowDB.goto_next_node()
	StoryFlowDB.debug_print_state("after goto_next_node (final)")

	# クリア演出はここでは行わず、event_09 を読み終えたあと
	# ClearScene でまとめて表示する方針にする
	scene.get_tree().change_scene_to_file("res://scenes/event/EventScene.tscn")
