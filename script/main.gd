extends Node2D


# 精灵表 face_roman.png 从左到右的 5 帧。
enum Face {
	TOO_HIGH, # 猜得太大
	HIGH, # 略大
	CORRECT, # 正确
	LOW, # 略小
	TOO_LOW, # 太小
}

# 差值 → 倾角：按数量级做对数归一化，让 1 ~ 10^10 的差值比较均匀地
# 分配到 [MIN_TILT, MAX_TILT]。差值为 0 时保持水平。
#
# 支点在 y=25、盘臂长 66px，超过约 22° 后抬起的托盘会跑出画面。
# 这是有意保留的：大差值越夸张，越能直观表现数量级差距。
const MIN_TILT := PI / 24.0
const MAX_TILT := PI / 3.0
const MAX_DIFF := 10_000_000_000.0
const TILT_TIME := 0.6

# 下一关地址从文本文件读取；文件不存在/为空/无效时默认重载当前场景。
const NEXT_SCENE_FILE := "res://next_scene.txt"

@export var NowLevel: int = 1;
# 当前场景的背景音乐；其他场景可以在检查器里覆盖。
@export var scene_music: AudioStream = preload("res://sound/music/roman.wav")

# 与目标值相差在这个比例以内算“略大/略小”，超过则算“大/小”。
@export_range(0.0, 1.0, 0.01) var face_near_ratio: float = 0.1

@onready var Stack: Sprite2D = $Stack
@onready var Plate1: Sprite2D = $Stack/Plate1
@onready var Plate2: Sprite2D = $Stack/Plate2
@onready var Calculator = $Calculator
@onready var Result = $Calculator/Result
@onready var Face64Px: Sprite2D = $Face64Px
@onready var Continue: BaseButton = $Continue
@onready var Music: AudioStreamPlayer = $Music
@onready var MusicButton: BaseButton = $MusicButton

var _tilt_tween: Tween
var _changing_scene := false


func _ready() -> void:
	Calculator.submitted.connect(_on_submitted)
	_apply_tilt(0.0)
	_setup_continue_button()
	_setup_audio()


func _on_submitted(value: int) -> void:
	Result.show_result(value)

	# 猜测值与目标值比较：Result 同时持有两者，Main 只负责表现。
	var target: int = Result.TargetNum
	var diff: int = value - target
	_update_face(diff, target)
	_tilt_to(_diff_to_tilt(diff))

	# 猜测过程中不显示；猜中后一直显示，之后再猜错也不隐藏。
	if diff == 0:
		Continue.visible = true


func _update_face(diff: int, target: int) -> void:
	if diff == 0:
		Face64Px.frame = Face.CORRECT
		return

	# 以目标值的比例作为“略大/略小”的容差；target 为 0 时至少留 1。
	var near_limit: int = maxi(1, int(abs(target) * face_near_ratio))
	if diff > 0:
		Face64Px.frame = Face.HIGH if diff <= near_limit else Face.TOO_HIGH
	else:
		Face64Px.frame = Face.LOW if -diff <= near_limit else Face.TOO_LOW


func _diff_to_tilt(diff: int) -> float:
	if diff == 0:
		return 0.0

	# 用 log(1+diff) 而不是 diff / 10^10：线性归一化会让绝大多数差值
	# 挤在 0 附近，角度几乎看不出变化。
	var t := log(float(abs(diff)) + 1.0) / log(MAX_DIFF + 1.0)
	var angle := lerpf(MIN_TILT, MAX_TILT, clampf(t, 0.0, 1.0))

	# Godot 中正旋转是顺时针（右盘下沉）。
	# 猜大 → 左盘下沉 → 取负角度。
	return -angle if diff > 0 else angle


func _tilt_to(angle: float) -> void:
	if _tilt_tween and _tilt_tween.is_valid():
		_tilt_tween.kill()

	_tilt_tween = create_tween()
	_tilt_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tilt_tween.tween_method(_apply_tilt, Stack.rotation, angle, TILT_TIME)


func _apply_tilt(angle: float) -> void:
	Stack.rotation = angle
	# 横梁转动时让托盘保持竖直，而不是跟着一起翻。
	Plate1.global_rotation = 0.0
	Plate2.global_rotation = 0.0


# --- Continue 按钮与场景跳转 ---------------------------------------------

func _setup_continue_button() -> void:
	# 开局隐藏，猜中目标值后才在 _on_submitted 里显示。
	Continue.visible = false
	if not Continue.pressed.is_connected(_on_continue_pressed):
		Continue.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	if _changing_scene:
		return
	_changing_scene = true

	# 通关后至少解锁下一关；重玩旧关时 max 保证进度不会回退。
	Level.level_present = maxi(Level.level_present, NowLevel + 1)

	# 读取下一关地址；没有配置或路径无效时回到“读取自身”。
	var target := _read_next_scene_path()
	if target.is_empty() or not ResourceLoader.exists(target):
		target = _current_scene_path()

	if target.is_empty():
		_changing_scene = false
		return

	var error := get_tree().change_scene_to_file(target)
	if error != OK:
		_changing_scene = false
		push_error("Continue: failed to load '%s' (error %d)" % [target, error])


func _read_next_scene_path() -> String:
	if not FileAccess.file_exists(NEXT_SCENE_FILE):
		return ""
	var file := FileAccess.open(NEXT_SCENE_FILE, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


# --- 音频 ---------------------------------------------------------------

func _setup_audio() -> void:
	if scene_music != null:
		Music.stream = scene_music
		# 让当前场景的 BGM 循环；不依赖 wav 的导入循环设置。
		if Music.stream is AudioStreamWAV:
			var wav := Music.stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		Music.play()

	# 这个 toggle 按钮的按下态对应“音乐关闭”（图标倒下）；
	# 默认不按下 = 开启，所以开局先播放音乐。
	MusicButton.focus_mode = Control.FOCUS_NONE
	MusicButton.button_pressed = false
	if not MusicButton.toggled.is_connected(_on_music_toggled):
		MusicButton.toggled.connect(_on_music_toggled)


func _on_music_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Music.stop()
	else:
		# stop() 后重新 play() 会从头播放当前场景的 BGM。
		Music.play()
