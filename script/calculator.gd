extends Sprite2D
@onready var Button0 = $Button0;
@onready var Button1 = $Button1;
@onready var Button2 = $Button2;
@onready var Button3 = $Button3;
@onready var Button4 = $Button4;
@onready var Button5 = $Button5;
@onready var Button6 = $Button6;
@onready var Button7 = $Button7;
@onready var Button8 = $Button8;
@onready var Button9 = $Button9;
@onready var ButtonE = $ButtonE;
@onready var ButtonB = $ButtonB;
@onready var text = $Text;
@onready var Result = $Result;

# 上限 10^17（18 位），超过这个值就显示 ERROR
const MAX_VALUE = "100000000000000000"

var Num = "0"
var Overflow = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var DigitButtons = [Button0, Button1, Button2, Button3, Button4, Button5, Button6, Button7, Button8, Button9]
	for i in DigitButtons.size():
		DigitButtons[i].pressed.connect(_on_digit_pressed.bind(i))
	ButtonB.pressed.connect(_on_back_pressed)
	ButtonE.pressed.connect(_on_equals_pressed)
	text.text = Num


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_digit_pressed(Digit: int) -> void:
	# 溢出状态下按数字键：清零并从这个数字重新开始
	if Overflow:
		Num = "0"
		Overflow = false
	# Num * 10 + Digit，前导 0 不保留
	if Num == "0":
		Num = str(Digit)
	else:
		Num += str(Digit)
	Overflow = _is_overflow(Num)
	text.text = "ERROR" if Overflow else Num


func _on_equals_pressed() -> void:
	# ERROR 或空输入不输出
	if Overflow or Num.is_empty():
		return
	Result.show_maya(int(Num))


func _on_back_pressed() -> void:
	# 删除一位；删空后显示空白而不是 0
	if Num.length() > 0:
		Num = Num.substr(0, Num.length() - 1)
	Overflow = _is_overflow(Num)
	text.text = "ERROR" if Overflow else Num


func _is_overflow(Value: String) -> bool:
	if Value.length() != MAX_VALUE.length():
		return Value.length() > MAX_VALUE.length()
	return Value > MAX_VALUE
