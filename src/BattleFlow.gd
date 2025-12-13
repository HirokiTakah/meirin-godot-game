extends Object

# ここだけ別名で preload して使う（グローバルクラス名との衝突を避ける）
const MessageHelperScript := preload("res://src/MessageHelper.gd")
const BattleEffects := preload("res://src/BattleEffects.gd")
const UiText := preload("res://src/UiText.gd")
# GameState / StoryFlowDB は Autoload シングルトン

const TYPEWRITER_SPEED: float = 0.01

# --- P2_T6: command actions entry point ---
static func apply_player_action(scene: Node, action_id: String) -> Dictionary:
	# scene は BattleScene を想定
	scene.processing_turn = true
	scene.set_attack_buttons_enabled(false)

	# プレイヤー行動
	var r1: Dictionary = await _do_player_action(scene, action_id)
	if not bool(r1.get("ok", false)):
		scene.processing_turn = false
		scene.set_attack_buttons_enabled(true)
		return r1

	# プレイヤー行動で敵が倒れたら、敵行動はスキップ
	if GameState.enemy_hp <= 0:
		r1["is_enemy_dead"] = true
		r1["is_player_dead"] = GameState.player_hp <= 0
		scene.processing_turn = false
		return r1

	# 敵行動（必ず行う）
	var r2: Dictionary = await _do_enemy_action(scene)

	r2["is_enemy_dead"] = GameState.enemy_hp <= 0
	r2["is_player_dead"] = GameState.player_hp <= 0
	scene.processing_turn = false
	return r2


static func _do_player_action(scene: Node, action_id: String) -> Dictionary:
	if action_id == "attack":
		return await _present_and_apply_player_attack(scene)
	if action_id == "guard":
		GameState.guard_active = true
		return await _present_status_only(scene, "Guard", "guard")
	if action_id == "inspire":
		GameState.inspire_active = true
		return await _present_status_only(scene, "Inspire", "inspire")

	return {
		"ok": false,
		"action_id": action_id,
		"move_name": "",
		"result_msg": "Unknown action",
		"battle_msg": "",
		"player_hp_after": GameState.player_hp,
		"enemy_hp_after": GameState.enemy_hp,
		"player_hp_max": GameState.player_max_hp,
		"enemy_hp_max": GameState.enemy_max_hp,
		"is_player_dead": GameState.player_hp <= 0,
		"is_enemy_dead": GameState.enemy_hp <= 0
	}


static func _do_enemy_action(scene: Node) -> Dictionary:
	return await _present_and_apply_enemy_attack(scene)


static func _present_status_only(scene: Node, move_name: String, action_id: String) -> Dictionary:
	scene.move_name_label.text = move_name

	var msg: String = move_name + "!"
	await MessageHelper.typewriter_show(scene, scene.battle_text, msg, scene.TYPEWRITER_SPEED)

	# HP変化なし（必要なら短い間を追加してもOK）
	# await scene.get_tree().create_timer(0.15).timeout

	return {
		"ok": true,
		"action_id": action_id,
		"move_name": move_name,
		"result_msg": msg,
		"battle_msg": "",
		"player_hp_after": GameState.player_hp,
		"enemy_hp_after": GameState.enemy_hp,
		"player_hp_max": GameState.player_max_hp,
		"enemy_hp_max": GameState.enemy_max_hp,
		"is_player_dead": GameState.player_hp <= 0,
		"is_enemy_dead": GameState.enemy_hp <= 0
	}


static func _present_and_apply_player_attack(scene: Node) -> Dictionary:
	scene.move_name_label.text = "Attack"

	var calc: Dictionary = GameState.compute_player_attack_fixed()

	var msg: String = "Attack!"
	if bool(calc.get("miss", false)):
		msg = "Attack missed!"
	elif bool(calc.get("critical", false)):
		msg = "Critical hit!"

	await MessageHelper.typewriter_show(scene, scene.battle_text, msg, scene.TYPEWRITER_SPEED)

	await BattleEffects.play_player_attack_fx(scene.meirin_sprite)
	if int(calc.get("dmg_to_enemy", 0)) > 0:
		await BattleEffects.play_enemy_hit_fx(scene.enemy_sprite)

	GameState.apply_fixed_result(calc)
	await scene.animate_hp_bars_to_current(0.25)

	return {
		"ok": true,
		"action_id": "attack",
		"move_name": "Attack",
		"result_msg": msg,
		"battle_msg": "",
		"player_hp_after": GameState.player_hp,
		"enemy_hp_after": GameState.enemy_hp,
		"player_hp_max": GameState.player_max_hp,
		"enemy_hp_max": GameState.enemy_max_hp,
		"is_player_dead": GameState.player_hp <= 0,
		"is_enemy_dead": GameState.enemy_hp <= 0
	}


static func _present_and_apply_enemy_attack(scene: Node) -> Dictionary:
	scene.move_name_label.text = "Enemy Attack"

	var calc: Dictionary = GameState.compute_enemy_attack_fixed()

	var msg: String = "Enemy attacks!"
	if bool(calc.get("miss", false)):
		msg = "Enemy missed!"
	elif bool(calc.get("critical", false)):
		msg = "Enemy critical!"

	await MessageHelper.typewriter_show(scene, scene.battle_text, msg, scene.TYPEWRITER_SPEED)

	await BattleEffects.play_enemy_attack_fx(scene.enemy_sprite)
	scene.show_meirin_damage()
	if int(calc.get("dmg_to_player", 0)) > 0:
		await BattleEffects.play_player_hit_fx(scene.meirin_sprite)

	GameState.apply_fixed_result(calc)
	await scene.animate_hp_bars_to_current(0.25)

	return {
		"ok": true,
		"action_id": "enemy_attack",
		"move_name": "Enemy Attack",
		"result_msg": msg,
		"battle_msg": "",
		"player_hp_after": GameState.player_hp,
		"enemy_hp_after": GameState.enemy_hp,
		"player_hp_max": GameState.player_max_hp,
		"enemy_hp_max": GameState.enemy_max_hp,
		"is_player_dead": GameState.player_hp <= 0,
		"is_enemy_dead": GameState.enemy_hp <= 0
	}


# 1ターン分の処理
# BattleFlow.gd の process_turn 内だけ差し替え（概念）

static func process_turn(scene: Node, player_choice: int) -> void:
	if scene.processing_turn:
		return
	scene.processing_turn = true
	scene.set_attack_buttons_enabled(false)

	# 変更：HP確定しない計算だけ
	var result: Dictionary = GameState.compute_turn(player_choice)
	if result.get("result", "") in ["gameover", "ended"]:
		scene.processing_turn = false
		scene.set_attack_buttons_enabled(true)
		return

	# 先にテキスト（after を使ったテキスト）
	var result_msg: String = String(result.get("result_msg", ""))
	var battle_msg: String = String(result.get("battle_msg", ""))
	var combined_text: String = scene._make_round_text(result_msg, battle_msg)
	if combined_text != "":
		await MessageHelperScript.typewriter_show(scene, scene.battle_text, combined_text, TYPEWRITER_SPEED)

	# モーション（ここは現行踏襲。ただし LOSE は「HPが残っている条件」を外す）
	await _handle_post_round_fx_only(scene, result)

	# ここでHP確定
	GameState.apply_turn(result)

	# ここでHPバーを減らす（Tween）
	await scene.animate_hp_bars_to_current(0.25)

	# 特殊：ステージ6ドレイン開始（現行仕様に合わせるなら、HP確定後に開始でもOK）
	if GameState.game_stage == 6 and bool(result.get("start_drain", false)):
		scene.start_stage6_drain()
		scene.processing_turn = false
		return

	# 勝敗判定（apply後のHPで見る）
	if GameState.player_hp <= 0:
		await scene.play_defeat_sequence()
		scene.processing_turn = false
		return

	if GameState.enemy_hp <= 0:
		await _handle_enemy_defeated(scene)
		scene.processing_turn = false
		return

	scene.set_attack_buttons_enabled(true)
	scene.update_meirin_idle()
	scene.processing_turn = false


# 追加：演出だけをする関数（HP条件に依存しない）
static func _handle_post_round_fx_only(scene: Node, result: Dictionary) -> void:
	var round_result: int = int(result.get("round_result", -1))
	if round_result == GameState.ROUND_WIN:
		await BattleEffects.play_player_attack_fx(scene.meirin_sprite)
		await BattleEffects.play_enemy_hit_fx(scene.enemy_sprite)
	elif round_result == GameState.ROUND_LOSE:
		await BattleEffects.play_enemy_attack_fx(scene.enemy_sprite)
		scene.show_meirin_damage()
		await BattleEffects.play_player_hit_fx(scene.meirin_sprite)
		scene.update_meirin_idle()



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
			await MessageHelperScript.typewriter_show(
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
				await MessageHelperScript.typewriter_show(
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
				await MessageHelperScript.typewriter_show(
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
	
	
