# res://src/StoryFlowDB.gd
extends Node

const STORY_FLOW_JSON_PATH: String = "res://data/story_flow.json"
const EVENTS_JSON_PATH: String = "res://data/events.json"

var _nodes: Array = []          # story_flow.json の nodes
var _events: Dictionary = {}    # events.json の events
var _current_index: int = 0     # いまどの node にいるか（0 始まり）


func _ready() -> void:
	_load_story_flow()
	_load_events()


# -------------------------------------------------
# story_flow.json 読み込み
# -------------------------------------------------
func _load_story_flow() -> void:
	_nodes.clear()

	if not ResourceLoader.exists(STORY_FLOW_JSON_PATH):
		push_warning("story_flow.json が見つかりません: %s" % STORY_FLOW_JSON_PATH)
		return

	var file := FileAccess.open(STORY_FLOW_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("story_flow.json を開けませんでした")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("story_flow.json の形式が不正です")
		return

	var dict := parsed as Dictionary
	var nodes_val: Variant = dict.get("nodes", [])
	if typeof(nodes_val) != TYPE_ARRAY:
		push_warning("story_flow.json に nodes 配列がありません")
		return

	_nodes = nodes_val
	_current_index = 0


# -------------------------------------------------
# events.json 読み込み
# -------------------------------------------------
func _load_events() -> void:
	_events.clear()

	if not ResourceLoader.exists(EVENTS_JSON_PATH):
		push_warning("events.json が見つかりません: %s" % EVENTS_JSON_PATH)
		return

	var file := FileAccess.open(EVENTS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("events.json を開けませんでした")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("events.json の形式が不正です")
		return

	var dict := parsed as Dictionary
	var ev: Variant = dict.get("events", {})
	if typeof(ev) != TYPE_DICTIONARY:
		push_warning("events.json に events オブジェクトがありません")
		return

	_events = ev


# -------------------------------------------------
# 現在ノード操作
# -------------------------------------------------
func reset_story() -> void:
	_current_index = 0


func get_current_node() -> Dictionary:
	if _nodes.is_empty():
		return {}
	if _current_index < 0 or _current_index >= _nodes.size():
		return {}
	var node_v: Variant = _nodes[_current_index]
	if typeof(node_v) != TYPE_DICTIONARY:
		return {}
	return node_v as Dictionary


func goto_next_node() -> void:
	if _nodes.is_empty():
		return
	if _current_index < _nodes.size() - 1:
		_current_index += 1


func has_next_node() -> bool:
	if _nodes.is_empty():
		return false
	return _current_index < _nodes.size() - 1


func is_current_event() -> bool:
	var node := get_current_node()
	return String(node.get("type", "")) == "event"


func is_current_battle() -> bool:
	var node := get_current_node()
	return String(node.get("type", "")) == "battle"


# -------------------------------------------------
# イベント内容取得（EventScene 用）
# -------------------------------------------------
func get_current_event_lines() -> Array:
	var node := get_current_node()
	if String(node.get("type", "")) != "event":
		return []

	var script_id: String = String(node.get("script_id", ""))
	if script_id == "":
		return []

	if not _events.has(script_id):
		return []

	var evt_v: Variant = _events[script_id]
	if typeof(evt_v) != TYPE_DICTIONARY:
		return []

	var evt := evt_v as Dictionary
	var lines_val: Variant = evt.get("lines", [])
	if typeof(lines_val) != TYPE_ARRAY:
		return []

	return lines_val as Array


# -------------------------------------------------
# バトルとステージ番号の対応
# -------------------------------------------------
# 「いまのストーリー位置で、何回目のバトルか」を返す。
# 既存 GameState.game_stage (1,2,3...) と合わせる用途。
func get_battle_index_upto_current() -> int:
	if _nodes.is_empty():
		return 0

	var count: int = 0
	for i in _nodes.size():
		var node_v: Variant = _nodes[i]
		if typeof(node_v) != TYPE_DICTIONARY:
			continue

		var node := node_v as Dictionary
		var t: String = String(node.get("type", ""))
		if t == "battle":
			count += 1

		if i == _current_index:
			break

	return count


# -------------------------------------------------
# デバッグ用：現在の状態をログに出す
# -------------------------------------------------
func debug_print_state(label: String = "") -> void:
	var prefix: String = label
	if prefix == "":
		prefix = "StoryFlowDB"

	var node_info: String = ""
	var is_event: bool = false

	if _current_index >= 0 and _current_index < _nodes.size():
		var node := get_current_node()
		var id_str: String = String(node.get("id", ""))
		var type_str: String = String(node.get("type", ""))
		node_info = "id=%s, type=%s" % [id_str, type_str]
		is_event = (type_str == "event")
	else:
		node_info = "index out of range"

	print(
		"%s: index=%d, %s, is_event=%s" % [
			prefix,
			_current_index,
			node_info,
			str(is_event)
		]
	)
