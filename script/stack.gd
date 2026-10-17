extends Node2D
@onready var Stack = $Stack
@onready var Plate1 = $Stack/Plate1
@onready var Plate2 = $Stack/Plate2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass

func _unhandled_input(event: InputEvent) -> void:
	# 按空格驱动所有生成的 Animal 挪动
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		Stack.rotate(0.05)
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		Stack.rotate(-0.05)
	Plate1.set_global_rotation(0);
	Plate2.set_global_rotation(0);
