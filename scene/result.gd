extends Sprite2D

@onready var ResultText: Label = $Text

enum NumSet {
	ROMAN,
	MAYA,
	CHINESE,
	STICK,
	BABYLON
}

# Result 是一个静态输出口：外部设置 ResultNum / ResultSet 后调用 _show()。
@export var ResultNum: int = 0
@export var ResultSet: NumSet = NumSet.MAYA

const NORMAL_FONT = preload("res://font/ChillBitmap_7px.ttf")
const MAYA_FONT = preload("res://art/font/maya.png")

const FONT_SIZE := 7
const MAYA_RECT_POS := Vector2(160, 87)
const MAYA_RECT_SIZE := Vector2(108, 114)
const TEXT_RECT_POS := Vector2(180, 110)
const TEXT_RECT_SIZE := Vector2(70, 70)

# 玛雅字体按 0,1..9,A..J,K 的顺序映射：K 是“多位数字里的 0”。
const MAYA_DIGITS := "0123456789ABCDEFGHIJ"
const CHINESE_DIGITS := "零一二三四五六七八九"
const CHINESE_PLACES: Array[int] = [1000, 100, 10, 1]
const CHINESE_UNITS: Array[String] = ["千", "百", "十", ""]
const CHINESE_BIG_UNITS: Array[String] = ["", "万", "亿", "兆", "京"]

const ROMAN_VALUES: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
const ROMAN_SYMBOLS: Array[String] = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ResultText.add_theme_constant_override("line_spacing", 0)
	_show()

# 外部输出数字时调用：
# Result.show_result(1234, Result.NumSet.MAYA)
func show_result(num: int, num_set: NumSet) -> void:
	ResultNum = num
	ResultSet = num_set
	_show()

# 固定用玛雅数字输出。
func show_maya(num: int) -> void:
	show_result(num, NumSet.MAYA)

func _show() -> void:
	var text := ""
	var font: Font = NORMAL_FONT
	var wrap: int = TextServer.AUTOWRAP_WORD_SMART

	# 静态状态机：按当前数字系统选择格式化方式。
	match ResultSet:
		NumSet.ROMAN:
			text = _to_roman(ResultNum)
		NumSet.MAYA:
			text = _to_maya(ResultNum)
			font = MAYA_FONT
			wrap = TextServer.AUTOWRAP_OFF
		NumSet.CHINESE:
			text = _to_chinese(ResultNum)
		NumSet.STICK:
			text = _to_stick(ResultNum)
		NumSet.BABYLON:
			text = _to_babylon(ResultNum)
		_:
			text = str(ResultNum)

	if ResultSet == NumSet.MAYA:
		ResultText.position = MAYA_RECT_POS
		ResultText.size = MAYA_RECT_SIZE
	else:
		ResultText.position = TEXT_RECT_POS
		ResultText.size = TEXT_RECT_SIZE

	ResultText.add_theme_font_override("font", font)
	ResultText.add_theme_font_size_override("font_size", FONT_SIZE)
	ResultText.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ResultText.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ResultText.autowrap_mode = wrap
	ResultText.text = text


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

		result += _chinese_group(group, result.is_empty())
		result += CHINESE_BIG_UNITS[i]
		zero_pending = false

	return result


func _chinese_group(group: int, is_leading: bool) -> String:
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

			# 10 在最前面时写“十”，不写“一十”。
			if i == 2 and digit == 1 and is_leading and result.is_empty():
				result += "十"
			else:
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
