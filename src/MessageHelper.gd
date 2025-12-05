# res://src/MessageHelper.gd
extends Node
class_name MessageHelper

# 結果＋セリフのテキストを組み立てる
# 1行目：▶結果
# 2行目：メイリンのセリフ（内部の改行はスペースにする）
static func make_round_text(result_msg: String, battle_msg: String) -> String:
	var clean_battle := battle_msg.replace("\n", " ")
	clean_battle = clean_battle.strip_edges()

	if result_msg == "" and clean_battle == "":
		return ""
	if result_msg == "":
		return clean_battle
	if clean_battle == "":
		return "▶%s" % result_msg

	# 結果1行目、セリフ2行目
	return "▶%s\n%s" % [result_msg, clean_battle]


# ドラクエ風に1文字ずつ表示する
static func typewriter_show(owner: Node, label: Label, text: String, speed: float) -> void:
	if label == null:
		return

	label.text = ""
	for i in text.length():
		label.text += text[i]
		await owner.get_tree().create_timer(speed).timeout
