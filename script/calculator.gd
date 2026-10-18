extends Sprite2D

# 按下等号时广播当前输入值，由场景根节点决定如何显示和比较。
signal submitted(value: int)

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
@onready var Sfx: AudioStreamPlayer = $Sfx;

# 上限 （10 位），超过这个值就显示 ERROR
const MAX_VALUE = "10000000000"

const CLICK_SFX = preload("res://sound/sfx/click.mp3")

var Num = "0"
var Overflow = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var DigitButtons = [Button0, Button1, Button2, Button3, Button4, Button5, Button6, Button7, Button8, Button9]
	for i in DigitButtons.size():
		DigitButtons[i].focus_mode = Control.FOCUS_NONE
		DigitButtons[i].pressed.connect(_on_digit_pressed.bind(i))
	# 禁用焦点，避免鼠标点过的按钮抢走 Enter（Enter 已映射为等号）。
	ButtonB.focus_mode = Control.FOCUS_NONE
	ButtonE.focus_mode = Control.FOCUS_NONE
	ButtonB.pressed.connect(_on_back_pressed)
	ButtonE.pressed.connect(_on_equals_pressed)
	text.text = Num

	Sfx.stream = CLICK_SFX

	var spaced := FontVariation.new()
	spaced.base_font = preload("res://font/ChillBitmapSE_7px.ttf")
	spaced.spacing_glyph = 6

	for key in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		text.add_theme_font_override(key, spaced)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# 键盘输入：数字键 1~0（含小键盘）对应数字键，Backspace 对应退格，Enter 对应等于。
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var key := key_event.keycode
	var digit := -1
	if key >= KEY_0 and key <= KEY_9:
		digit = key - KEY_0
	elif key >= KEY_KP_0 and key <= KEY_KP_9:
		digit = key - KEY_KP_0

	if digit >= 0:
		_on_digit_pressed(digit)
		get_viewport().set_input_as_handled()
	elif key == KEY_BACKSPACE:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_on_equals_pressed()
		get_viewport().set_input_as_handled()


func _on_digit_pressed(Digit: int) -> void:
	_play_click()
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
	_play_click()
	# ERROR 或空输入不输出
	if Overflow or Num.is_empty():
		return
	submitted.emit(int(Num))



func _on_back_pressed() -> void:
	_play_click()
	# 删除一位；删空后显示空白而不是 0
	if Num.length() > 0:
		Num = Num.substr(0, Num.length() - 1)
	Overflow = _is_overflow(Num)
	text.text = "ERROR" if Overflow else Num


func _is_overflow(Value: String) -> bool:
	if Value.length() != MAX_VALUE.length():
		return Value.length() > MAX_VALUE.length()
	return Value > MAX_VALUE


# 所有计算器输入（鼠标或键盘）统一走这里发声。
func _play_click() -> void:
	Sfx.play()
