extends Node2D

# 关卡按钮名 → 关卡场景路径。
# 已完成的关卡填路径；未完成的先留空，按钮已连接但点击不会跳转。
const LEVEL_SCENES := {
	"Roman1": "res://scene/roman.tscn",
	"Maya3": "res://scene/maya.tscn",
	# TODO: 以下关卡完成后填入对应场景路径。
	"Aarbic2": "",
	"Chinese4": "",
	"Barbylon5": "",
	"Robot0": "",
}

var _changing_scene := false


func _ready() -> void:
	# 自动连接场景里的所有按钮。以后新增关卡按钮不用改连接代码，
	# 只要在 LEVEL_SCENES 里补上“节点名 → 场景路径”。
	for child in get_children():
		if child is BaseButton:
			child.pressed.connect(_on_level_pressed.bind(String(child.name)))


func _on_level_pressed(level_name: String) -> void:
	if _changing_scene:
		return

	var scene_path: String = LEVEL_SCENES.get(level_name, "")
	if scene_path.is_empty():
		# 该关还没做，保留按钮但不跳转。
		return

	if not ResourceLoader.exists(scene_path):
		push_error("MainPage: level scene not found: " + scene_path)
		return

	_changing_scene = true
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_changing_scene = false
		push_error("MainPage: failed to load '%s' (error %d)" % [scene_path, error])
