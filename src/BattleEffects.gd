extends Object

# 既存：メイリンダメージ（赤フラッシュ＋揺れ）
static func play_player_hit_fx(meirin_sprite: Sprite2D) -> void:
	if meirin_sprite == null:
		return

	var tree := meirin_sprite.get_tree()
	if tree == null:
		return

	var original_pos := meirin_sprite.position
	var original_modulate := meirin_sprite.modulate

	var tween := tree.create_tween()
	var hit_pos1 := original_pos + Vector2(-4, 0)
	var hit_pos2 := original_pos + Vector2(4, 0)

	# 赤く点滅
	tween.tween_property(meirin_sprite, "modulate", Color(1, 0.4, 0.4, 1), 0.05)
	tween.tween_property(meirin_sprite, "modulate", original_modulate, 0.05)

	# 軽い左右揺れ
	tween.parallel().tween_property(meirin_sprite, "position", hit_pos1, 0.04)
	tween.tween_property(meirin_sprite, "position", hit_pos2, 0.04)
	tween.tween_property(meirin_sprite, "position", original_pos, 0.04)

	await tween.finished


# プレイヤー攻撃時の前進（赤くならない）
static func play_player_attack_fx(meirin_sprite: Sprite2D) -> void:
	if meirin_sprite == null:
		return

	var tree := meirin_sprite.get_tree()
	if tree == null:
		return

	var original_pos := meirin_sprite.position
	var tween := tree.create_tween()
	var forward := original_pos + Vector2(20, 0)

	tween.tween_property(meirin_sprite, "position", forward, 0.08)
	tween.tween_property(meirin_sprite, "position", original_pos, 0.08)

	await tween.finished


# 敵が攻撃するときの前進
static func play_enemy_attack_fx(enemy_sprite: Sprite2D) -> void:
	if enemy_sprite == null:
		return

	var tree := enemy_sprite.get_tree()
	if tree == null:
		return

	var original_pos := enemy_sprite.position
	var tween := tree.create_tween()
	var forward := original_pos + Vector2(-20, 0)

	tween.tween_property(enemy_sprite, "position", forward, 0.08)
	tween.tween_property(enemy_sprite, "position", original_pos, 0.08)

	await tween.finished


# 敵ダメージ（赤フラッシュ＋揺れ）
static func play_enemy_hit_fx(enemy_sprite: Sprite2D) -> void:
	if enemy_sprite == null:
		return

	var tree := enemy_sprite.get_tree()
	if tree == null:
		return

	var original_pos := enemy_sprite.position
	var original_modulate := enemy_sprite.modulate

	var tween := tree.create_tween()
	var hit_pos1 := original_pos + Vector2(-6, 0)
	var hit_pos2 := original_pos + Vector2(6, 0)

	# 赤く点滅
	tween.tween_property(enemy_sprite, "modulate", Color(1, 0.4, 0.4, 1), 0.05)
	tween.tween_property(enemy_sprite, "modulate", original_modulate, 0.05)

	# 左右揺れ
	tween.parallel().tween_property(enemy_sprite, "position", hit_pos1, 0.04)
	tween.tween_property(enemy_sprite, "position", hit_pos2, 0.04)
	tween.tween_property(enemy_sprite, "position", original_pos, 0.04)

	await tween.finished
