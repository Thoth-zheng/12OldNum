extends Sprite2D

@onready var ResultText: Label = $Text
@onready var TargetText: Label = $TargetValue

enum NumSet {
	ROMAN,
	MAYA,
	CHINESE,
	STICK,
	BABYLON,
	ARABIC,
	ROBOT
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
const ARABIC_FONT = preload("res://art/font/arabic.png")
const BABYLON_FONT = preload("res://art/font/babylon.png")

# Maya 的图形字体原生 7px；中文/符号用 16px。
# 文件名里的 7px 指字形的像素高度，字体实际按 8px 行高设计；
# 用 font_size=8 才能落在像素网格上，否则会出现抗锯齿虚边。
const MAYA_FONT_SIZE := 7
const ROMAN_FONT_SIZE := 8
const ARABIC_FONT_SIZE := 5 # arabic.png 每格 5x5，按原生尺寸渲染
const ARABIC_GLYPH_SPACING := 1 # 字形靠左，字间留 1px 防止相邻数字粘连
const BABYLON_FONT_SIZE := 16 # babylon.png 每格 16x16
# 60 进制每一位固定用两个字符：十位（0=空白，1..5=A..E）+ 个位（0..9）。
const BABYLON_TENS := "0ABCDE"
const BABYLON_ONES := "0123456789"
const TEXT_FONT_SIZE := 16
const MAYA_LINE_SPACING := 2 # 玛雅数字上下叠放，至少留 2px 防止横杠粘连
const RESULT_COLOR := Color(0.05882353, 0.21960784, 0.05882353, 1) # #0f380f，与计算器文字一致

const MAYA_RECT_POS := Vector2(160, 87)
const MAYA_RECT_SIZE := Vector2(108, 114)
# 其他关卡共用的结果框；China 使用场景中 Text 摆好的上方对话框位置。
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

var _arabic_spaced_font: FontVariation
var _china_result_pos: Vector2
var _china_result_size: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# China 的结果文字放在上方对话框里，位置由场景中的 Text 节点决定。
	_china_result_pos = ResultText.position
	_china_result_size = ResultText.size
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
	var line_chars := 0
	if ResultSet == NumSet.CHINESE:
		line_chars = _chinese_line_chars(TargetText.size.x)
	TargetText.text = _format(num, line_chars)


func _format(num: int, chinese_line_chars: int = 0) -> String:
	# 静态状态机：按当前数字系统选择格式化方式。
	match ResultSet:
		NumSet.ROMAN:
			return _to_roman(num)
		NumSet.MAYA:
			return _to_maya(num)
		NumSet.CHINESE:
			return _to_chinese_rtl(num, chinese_line_chars)
		NumSet.STICK:
			return _to_stick(num)
		NumSet.BABYLON:
			return _to_babylon(num)
		NumSet.ARABIC:
			return _to_arabic(num)
		NumSet.ROBOT:
			return _to_binary(num)
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
		NumSet.BABYLON:
			font = BABYLON_FONT
			font_size = BABYLON_FONT_SIZE
			wrap = TextServer.AUTOWRAP_ARBITRARY
		NumSet.ARABIC:
			font = _get_arabic_font()
			font_size = ARABIC_FONT_SIZE
			wrap = TextServer.AUTOWRAP_OFF
		NumSet.ROBOT:
			# 二进制位数多，用 7px 像素字体保证长串也能放进结果框。
			font = ROMAN_FONT
			font_size = ROMAN_FONT_SIZE
			wrap = TextServer.AUTOWRAP_ARBITRARY

	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", line_spacing)
	label.add_theme_color_override("font_color", RESULT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = wrap


# 16px 中文每字占 16px，按 Label 宽度算出每行能放几个字。
func _chinese_line_chars(width: float) -> int:
	return maxi(1, int(width / TEXT_FONT_SIZE))


func _get_arabic_font() -> Font:
	if _arabic_spaced_font == null:
		_arabic_spaced_font = FontVariation.new()
		_arabic_spaced_font.base_font = ARABIC_FONT
		_arabic_spaced_font.spacing_glyph = ARABIC_GLYPH_SPACING
	return _arabic_spaced_font


func _show() -> void:
	# China 使用场景里给 Text 摆好的上方对话框位置。
	# 文本更新后再设尺寸：长文本把 Label 撑高后，下一次短结果才能缩回原框。
	if ResultSet == NumSet.CHINESE:
		_apply_style(ResultText)
		ResultText.text = _format(ResultNum, _chinese_line_chars(_china_result_size.x))
		ResultText.position = _china_result_pos
		ResultText.size = _china_result_size
		return

	# 结果气泡的框：玛雅是竖排图形，其他关卡使用统一的结果区域。
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


# China 从右往左书写，但换行仍从上到下：
# 先按正常顺序切行，再把每一行单独反转。
func _to_chinese_rtl(n: int, max_chars_per_line: int) -> String:
	var text := _to_chinese(n)
	if max_chars_per_line <= 0 or text.length() <= max_chars_per_line:
		return text.reverse()

	var lines := PackedStringArray()
	for start in range(0, text.length(), max_chars_per_line):
		var end := mini(start + max_chars_per_line, text.length())
		lines.append(text.substr(start, end - start).reverse())
	return "\n".join(lines)


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


# arabic.png 的字符范围是 0x30-0x39，即 ASCII 数字 0-9。
# 因此文本仍传普通十进制字符串，由字体负责显示成东阿拉伯数字形状。
func _to_arabic(n: int) -> String:
	return str(n)


# 机器人关卡：最简单的十进制 → 二进制。
func _to_binary(n: int) -> String:
	if n <= 0:
		return "0"

	var result := ""
	var value := n
	while value > 0:
		result = ("1" if value % 2 == 1 else "0") + result
		value /= 2
	return result


func _to_babylon(n: int) -> String:
	if n <= 0:
		return "0"

	var digits: Array[int] = []
	var value := n
	while value > 0:
		digits.push_front(value % 60)
		value /= 60

	var result := ""
	for digit in digits:
		# 每个 60 进制位固定两位：十位字符 + 个位字符。
		# 0 的字符格是空白的，用来占住进位后留下的位。
		result += BABYLON_TENS[digit / 10]
		result += BABYLON_ONES[digit % 10]
	return result


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
