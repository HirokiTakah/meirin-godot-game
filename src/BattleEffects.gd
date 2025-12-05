extends Object

# 攻撃エフェクト（めちゃ速い踏み込み）
static func play_attack_effect(meirin_sprite: Sprite2D, choice: int) -> void:
	if meirin_sprite == null:
		return

	var original_pos: Vector2 = meirin_sprite.position
	var original_scale: Vector2 = meirin_sprite.scale
	var original_mod: Color = meirin_sprite.modulate

	var dir := Vector2.RIGHT
	match choice:
		0:
			dir = Vector2.LEFT
		1:
			dir = Vector2.UP
		2:
			dir = Vector2.RIGHT

	dir = dir.normalized()

	var forward_pos := original_pos + dir * 55.0   # 大きく前へ
	var back_pos    := original_pos + dir * 15.0   # 少し戻り位置

	# 光らせる
	meirin_sprite.modulate = Color(1.15, 1.15, 1.3)

	var tween := meirin_sprite.create_tween()

	# めちゃ速い踏み込み（0.05秒）
	tween.tween_property(meirin_sprite, "position", forward_pos, 0.05)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(meirin_sprite, "scale", original_scale * 1.1, 0.05)

	# 軽く戻す（0.04秒）
	tween.tween_property(meirin_sprite, "position", back_pos, 0.04)
	tween.parallel().tween_property(meirin_sprite, "scale", original_scale * 1.02, 0.04)

	# 完全に戻す
	tween.tween_property(meirin_sprite, "position", original_pos, 0.03)
	tween.parallel().tween_property(meirin_sprite, "scale", original_scale, 0.03)

	await tween.finished

	# リセット
	meirin_sprite.position = original_pos
	meirin_sprite.scale    = original_scale
	meirin_sprite.modulate = original_mod


# プレイヤー用ダメージ演出（揺れ＋赤フラッシュ）
static func play_player_hit_fx(meirin_sprite: Sprite2D) -> void:
	if meirin_sprite == null:
		return

	var original_pos: Vector2 = meirin_sprite.position
	var original_mod: Color = meirin_sprite.modulate

	var steps := 4
	for i in steps:
		var offset := Vector2(
			randi_range(-4, 4),
			randi_range(-3, 3)
		)
		meirin_sprite.position = original_pos + offset
		meirin_sprite.modulate = Color(1.0, 0.5, 0.5)
		await meirin_sprite.get_tree().create_timer(0.03).timeout

		meirin_sprite.position = original_pos
		meirin_sprite.modulate = original_mod
		await meirin_sprite.get_tree().create_timer(0.03).timeout

	meirin_sprite.position = original_pos
	meirin_sprite.modulate = original_mod


# 敵用ダメージ演出（揺れ＋赤フラッシュ）
static func play_enemy_hit_fx(enemy_sprite: Sprite2D) -> void:
	if enemy_sprite == null:
		return

	var original_pos: Vector2 = enemy_sprite.position
	var original_mod: Color = enemy_sprite.modulate

	var steps := 4
	for i in steps:
		var offset := Vector2(
			randi_range(-4, 4),
			randi_range(-3, 3)
		)
		enemy_sprite.position = original_pos + offset
		enemy_sprite.modulate = Color(1.0, 0.5, 0.5)
		await enemy_sprite.get_tree().create_timer(0.03).timeout

		enemy_sprite.position = original_pos
		enemy_sprite.modulate = original_mod
		await enemy_sprite.get_tree().create_timer(0.03).timeout

	enemy_sprite.position = original_pos
	enemy_sprite.modulate = original_mod


# あいこのときのお互いの弾き返しアニメ
static func play_draw_effect(meirin_sprite: Sprite2D, enemy_sprite: Sprite2D) -> void:
	if meirin_sprite == null or enemy_sprite == null:
		return

	var m_pos: Vector2 = meirin_sprite.position
	var e_pos: Vector2 = enemy_sprite.position

	var d1 := (enemy_sprite.position - meirin_sprite.position).normalized()
	var d2 := -d1

	var m_back := m_pos + d1 * 20.0
	var e_back := e_pos + d2 * 20.0

	var tween := meirin_sprite.create_tween()
	tween.tween_property(meirin_sprite, "position", m_back, 0.05)
	tween.parallel().tween_property(enemy_sprite, "position", e_back, 0.05)

	tween.tween_property(meirin_sprite, "position", m_pos, 0.05)
	tween.parallel().tween_property(enemy_sprite, "position", e_pos, 0.05)

	await tween.finished

	meirin_sprite.position = m_pos
	enemy_sprite.position = e_pos
