extends Node2D

# 差值 → 倾角：按数量级做对数归一化，让 1 ~ 10^10 的差值比较均匀地
# 分配到 [MIN_TILT, MAX_TILT]。差值为 0 时保持水平。
#
# 支点在 y=25、盘臂长 66px，超过约 22° 后抬起的托盘会跑出画面。
# 这是有意保留的：大差值越夸张，越能直观表现数量级差距。
const MIN_TILT := PI / 24.0
const MAX_TILT := PI / 3.0
const MAX_DIFF := 10_000_000_000.0
const TILT_TIME := 0.6

@onready var Stack: Sprite2D = $Stack
@onready var Plate1: Sprite2D = $Stack/Plate1
@onready var Plate2: Sprite2D = $Stack/Plate2
@onready var Calculator = $Calculator
@onready var Result = $Calculator/Result

var _tilt_tween: Tween


func _ready() -> void:
	Calculator.submitted.connect(_on_submitted)
	_apply_tilt(0.0)


func _on_submitted(value: int) -> void:
	Result.show_result(value)

	# 猜测值与目标值比较：Result 同时持有两者，Main 只负责表现。
	var diff: int = value - Result.TargetNum
	_tilt_to(_diff_to_tilt(diff))


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
