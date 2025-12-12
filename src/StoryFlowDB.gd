# res://src/StoryFlowDB.gd
extends Node

const STORY_FLOW_JSON_PATH: String = "res://data/story_flow.json"
const EVENTS_JSON_PATH: String = "res://data/events.json"

var _nodes: Array[Dictionary] = []        # story_flow.json の nodes
var _events: Dictionary = {}              # events.json の events
var _current_index: int = 0               # いまどの node にいるか（0 始まり）


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

	var file: FileAccess = FileAccess.open(STORY_FLOW_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("story_flow.json を開けませんでした")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("story_flow.json の形式が不正です")
		return

	var dict: Dictionary = parsed as Dictionary
	var nodes_val: Variant = dict.get("nodes", [])
	if typeof(nodes_val) != TYPE_ARRAY:
		push_warning("story_flow.json に nodes 配列がありません")
		return

	# 型を Array[Dictionary] に揃える
	var raw_nodes: Array = nodes_val as Array
	for v: Variant in raw_nodes:
		if typeof(v) == TYPE_DICTIONARY:
			_nodes.append(v as Dictionary)

	_current_index = 0


# -------------------------------------------------
# events.json 読み込み
# -------------------------------------------------
func _load_events() -> void:
	_events.clear()

	if not ResourceLoader.exists(EVENTS_JSON_PATH):
		push_warning("events.json が見つかりません: %s" % EVENTS_JSON_PATH)
		return

	var file: FileAccess = FileAccess.open(EVENTS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("events.json を開けませんでした")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("events.json の形式が不正です")
		return

	var dict: Dictionary = parsed as Dictionary
	var ev: Variant = dict.get("events", {})
	if typeof(ev) != TYPE_DICTIONARY:
		push_warning("events.json に events オブジェクトがありません")
		return

	_events = ev as Dictionary


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
	return _nodes[_current_index]


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
	var node: Dictionary = get_current_node()
	return String(node.get("type", "")) == "event"


func is_current_battle() -> bool:
	var node: Dictionary = get_current_node()
	return String(node.get("type", "")) == "battle"


# -------------------------------------------------
# イベント内容取得（EventScene 用）
# -------------------------------------------------
func get_current_event_lines() -> Array[Dictionary]:
	if not is_current_event():
		return []

	var node: Dictionary = get_current_node()
	var event_id: String = String(node.get("event_id", ""))
	if event_id == "":
		return []

	if not _events.has(event_id):
		push_warning("Event not found: %s" % event_id)
		return []

	var event_obj_v: Variant = _events.get(event_id, {})
	if typeof(event_obj_v) != TYPE_DICTIONARY:
		return []

	var event_obj: Dictionary = event_obj_v as Dictionary
	var raw_lines_v: Variant = event_obj.get("lines", [])
	if typeof(raw_lines_v) != TYPE_ARRAY:
		return []

	var raw_lines: Array = raw_lines_v as Array
	var lines: Array[Dictionary] = []

	for v: Variant in raw_lines:
		if typeof(v) == TYPE_DICTIONARY:
			lines.append(v as Dictionary)

	return lines


# -------------------------------------------------
# バトルとステージ番号の対応
# -------------------------------------------------
# 「いまのストーリー位置で、何回目のバトルか」を返す。
# 既存 GameState.game_stage (1,2,3...) と合わせる用途。
func get_battle_index_upto_current() -> int:
	if _nodes.is_empty():
		return 0

	var count: int = 0
	for i: int in range(_nodes.size()):
		var node: Dictionary = _nodes[i]
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
		var node: Dictionary = get_current_node()
		var id_str: String = String(node.get("id", ""))
		var type_str: String = String(node.get("type", ""))
		node_info = "id=%s, type=%s" % [id_str, type_str]
		is_event = (type_str == "event")
	else:
		node_info = "index out of range"

	print("%s: index=%d, %s, is_event=%s" % [prefix, _current_index, node_info, str(is_event)])
