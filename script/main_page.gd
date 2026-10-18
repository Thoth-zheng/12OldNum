extends Node2D

# 关卡按钮名 → 关卡场景路径。
# 已完成的关卡填路径；未完成的先留空，按钮已连接但点击不会跳转。
const LEVEL_SCENES := {
	"Roman1": "res://scene/roman.tscn",
	"Maya3": "res://scene/maya.tscn",
	"Aarbic2": "res://scene/arabic.tscn",
	"Chinese4": "res://scene/china.tscn",
	"Barbylon5": "res://scene/babylon.tscn",
	"Robot0": "res://scene/robot.tscn",
}

# 按钮名 → 关卡序号（1~6），用于按通关进度控制按钮可见性。
const LEVEL_NUMBERS := {
	"Roman1": 1,
	"Aarbic2": 2,
	"Maya3": 3,
	"Chinese4": 4,
	"Barbylon5": 5,
	"Robot0": 6,
}

const CLICK_SFX = preload("res://sound/sfx/click.mp3")

@onready var Sfx: AudioStreamPlayer = $Sfx

var _changing_scene := false


func _ready() -> void:
	Sfx.stream = CLICK_SFX
	_update_progress_display()

	# 自动连接场景里的所有按钮。以后新增关卡按钮不用改连接代码，
	# 只要在 LEVEL_SCENES 里补上“节点名 → 场景路径”。
	for child in get_children():
		if child is BaseButton:
			child.pressed.connect(_on_level_pressed.bind(String(child.name)))


# 按 Level.level_present 显示已解锁关卡；全部通关后在选关界面上叠加 Thanks。
func _update_progress_display() -> void:
	var all_clear: bool = Level.level_present > LEVEL_SCENES.size()
	$Thanks.visible = all_clear

	for child in get_children():
		if child is BaseButton:
			var level_number: int = LEVEL_NUMBERS.get(String(child.name), 0)
			if level_number > 0:
				child.visible = level_number <= Level.level_present


func _on_level_pressed(level_name: String) -> void:
	if _changing_scene:
		return

	Sfx.play()

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
