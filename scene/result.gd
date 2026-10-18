extends Sprite2D

@onready var ResultText: Label = $Text
@onready var TargetText: Label = $TargetValue

enum NumSet {
	ROMAN,
	MAYA,
	CHINESE,
	STICK,
	BABYLON
}

# Result 是一个静态输出口：外部设置 ResultNum / ResultSet 后调用 _show()。
@export var ResultNum: int = 0
@export var ResultSet: NumSet = NumSet.ROMAN

# 目标值：ready 时显示一次，之后保持静态，不随猜测变化。
@export var TargetNum: int = 142857

# 中文/符号用 16px 保证清晰；罗马数字单独用原生 7px 字体。
const TEXT_FONT = preload("res://font/ChillBitmap_16px.ttf")
const ROMAN_FONT = preload("res://font/ChillBitmap_7px.ttf")
const MAYA_FONT = preload("res://art/font/maya.png")

# Maya 的图形字体原生 7px；中文/符号用 16px。
# 文件名里的 7px 指字形的像素高度，字体实际按 8px 行高设计；
# 用 font_size=8 才能落在像素网格上，否则会出现抗锯齿虚边。
const MAYA_FONT_SIZE := 7
const ROMAN_FONT_SIZE := 8
const TEXT_FONT_SIZE := 16
const MAYA_LINE_SPACING := 2 # 玛雅数字上下叠放，至少留 2px 防止横杠粘连
const RESULT_COLOR := Color(0.05882353, 0.21960784, 0.05882353, 1) # #0f380f，与计算器文字一致

const MAYA_RECT_POS := Vector2(160, 87)
const MAYA_RECT_SIZE := Vector2(108, 114)
# 中文最大 19 字，16px 下每行 4 字、共 5 行（80px）；
# 框高必须 >= 80px，否则最后一行会被裁掉。
const TEXT_RECT_POS := Vector2(180, 103)
const TEXT_RECT_SIZE := Vector2(70, 84)

# 玛雅字体按 0,1..9,A..J,K 的顺序映射：K 是“多位数字里的 0”。
const MAYA_DIGITS := "0123456789ABCDEFGHIJ"
# 繁体大写（银行金额风格）：零壹貳參肆伍陸柒捌玖，仟佰拾，萬億兆京。
const CHINESE_DIGITS := "零壹貳參肆伍陸柒捌玖"
const CHINESE_PLACES: Array[int] = [1000, 100, 10, 1]
const CHINESE_UNITS: Array[String] = ["仟", "佰", "拾", ""]
const CHINESE_BIG_UNITS: Array[String] = ["", "萬", "億", "兆", "京"]

const ROMAN_VALUES: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
const ROMAN_SYMBOLS: Array[String] = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	show_target(TargetNum)
	_show()


# 外部输出数字时调用：
# Result.show_result(1234)
func show_result(num: int) -> void:
	ResultNum = num
	_show()


# 目标值只在 ready 时显示一次；之后不随猜测变化。
func show_target(num: int) -> void:
	TargetNum = num
	_apply_style(TargetText)
	TargetText.text = _format(num)


func _format(num: int) -> String:
	# 静态状态机：按当前数字系统选择格式化方式。
	match ResultSet:
		NumSet.ROMAN:
			return _to_roman(num)
		NumSet.MAYA:
			return _to_maya(num)
		NumSet.CHINESE:
			return _to_chinese(num)
		NumSet.STICK:
			return _to_stick(num)
		NumSet.BABYLON:
			return _to_babylon(num)
		_:
			return str(num)


func _apply_style(label: Label) -> void:
	var font: Font = TEXT_FONT
	var font_size := TEXT_FONT_SIZE
	var line_spacing := 0
	var wrap: int = TextServer.AUTOWRAP_WORD_SMART

	match ResultSet:
		NumSet.ROMAN:
			font = ROMAN_FONT
			font_size = ROMAN_FONT_SIZE
		NumSet.MAYA:
			font = MAYA_FONT
			font_size = MAYA_FONT_SIZE
			line_spacing = MAYA_LINE_SPACING
			wrap = TextServer.AUTOWRAP_OFF

	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", line_spacing)
	label.add_theme_color_override("font_color", RESULT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = wrap


func _show() -> void:
	# 结果气泡的框：玛雅是竖排图形，其他是小字符文本。
	if ResultSet == NumSet.MAYA:
		ResultText.position = MAYA_RECT_POS
		ResultText.size = MAYA_RECT_SIZE
	else:
		ResultText.position = TEXT_RECT_POS
		ResultText.size = TEXT_RECT_SIZE

	_apply_style(ResultText)
	ResultText.text = _format(ResultNum)


func _to_roman(n: int) -> String:
	if n <= 0:
		return "N" # 罗马数字没有 0，用 nulla 的首字母
	if n < 4000:
		return _to_roman_basic(n)

	# 4000 以上用括号表示千倍：(I)=1000, ((I))=1000000，依此类推。
	var groups: Array[int] = []
	var value := n
	while value > 0:
		groups.push_front(value % 1000)
		value /= 1000

	var result := ""
	for i in groups.size():
		var group := groups[i]
		if group == 0:
			continue
		var depth := groups.size() - 1 - i
		result += "(".repeat(depth)
		result += _to_roman_basic(group)
		result += ")".repeat(depth)
	return result


func _to_roman_basic(n: int) -> String:
	var result := ""
	for i in ROMAN_VALUES.size():
		while n >= ROMAN_VALUES[i]:
			result += ROMAN_SYMBOLS[i]
			n -= ROMAN_VALUES[i]
	return result


func _to_maya(n: int) -> String:
	if n <= 0:
		return "0" # 单独 0 使用第 0 格

	var digits: Array[int] = []
	var value := n
	while value > 0:
		digits.push_front(value % 20)
		value /= 20

	var parts := PackedStringArray()
	for digit in digits:
		if digit == 0:
			parts.append("K") # 多位数字中的 0
		else:
			parts.append(MAYA_DIGITS[digit])
	return "\n".join(parts) # 高位在上，个位在下


# 中文输出使用繁体大写（银行金额风格）。
func _to_chinese(n: int) -> String:
	if n == 0:
		return "零"
	if n < 0:
		return "-" + _to_chinese(-n)

	var groups: Array[int] = []
	var value := n
	while value > 0:
		groups.append(value % 10000)
		value /= 10000

	var result := ""
	var zero_pending := false
	for i in range(groups.size() - 1, -1, -1):
		var group := groups[i]
		if group == 0:
			if not result.is_empty():
				zero_pending = true
			continue

		if not result.is_empty() and (zero_pending or group < 1000):
			result += "零"

		result += _chinese_group(group)
		result += CHINESE_BIG_UNITS[i]
		zero_pending = false

	return result


func _chinese_group(group: int) -> String:
	var result := ""
	var pending_zero := false

	for i in 4:
		var digit := (group / CHINESE_PLACES[i]) % 10
		if digit == 0:
			if not result.is_empty():
				pending_zero = true
		else:
			if pending_zero:
				result += "零"
				pending_zero = false

			result += CHINESE_DIGITS[digit] + CHINESE_UNITS[i]

	return result


func _to_stick(n: int) -> String:
	if n <= 0:
		return "0"
	if n > 50:
		return str(n) # 木棍计数是单进制，大数暂时回退成阿拉伯数字

	var parts := PackedStringArray()
	var groups := n / 5
	var remainder := n % 5
	for i in groups:
		parts.append("||||/")
	if remainder > 0:
		parts.append("|".repeat(remainder))
	return " ".join(parts)


func _to_babylon(n: int) -> String:
	if n <= 0:
		return "0"

	var digits: Array[int] = []
	var value := n
	while value > 0:
		digits.push_front(value % 60)
		value /= 60

	var parts := PackedStringArray()
	for digit in digits:
		if digit == 0:
			parts.append("0")
		else:
			var tens := digit / 10
			var ones := digit % 10
			parts.append("<".repeat(tens) + "|".repeat(ones))
	return " ".join(parts)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
