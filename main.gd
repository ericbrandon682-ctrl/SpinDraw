extends Node2D

const COLORS := [Color("ff5d73"), Color("4dd0e1"), Color("ffd166"), Color("95e06c")]

@onready var canvas: DrawCanvas = $DrawCanvas
@onready var tops: Node2D = $Tops
@onready var status: Label = $UI/Root/Panel/VBox/StatusLabel
@onready var spawn_btn: Button = $UI/Root/Panel/VBox/Buttons/SpawnButton
@onready var clear_btn: Button = $UI/Root/Panel/VBox/Buttons/ClearButton

var _spawn_count := 0

func _ready() -> void:
	spawn_btn.disabled = true
	status.text = "Draw a shape in the box, then press Spawn"
	canvas.stroke_changed.connect(_on_stroke_changed)
	spawn_btn.pressed.connect(_on_spawn)
	clear_btn.pressed.connect(_on_clear)

func _on_stroke_changed(is_valid: bool) -> void:
	spawn_btn.disabled = not is_valid
	if is_valid:
		var s := TopStats.from_area(canvas.build_shape()["area"])
		status.text = "HP %d | Mass %.1f | Speed %d | %d RPM" % [
			s.max_hp, s.mass, int(s.max_speed), s.rpm()]
	elif not canvas.is_drawing and canvas.points.size() > 0:
		status.text = "Shape too small or flat, try again"

func _on_spawn() -> void:
	var shape := canvas.build_shape()
	if shape.is_empty():
		return
	var stats := TopStats.from_area(shape["area"])
	var top := Top.new()
	top.setup(shape["hull_local"], shape["stroke_local"], stats,
			COLORS[_spawn_count % COLORS.size()])
	top.position = canvas.to_global(shape["center"])
	tops.add_child(top)
	_spawn_count += 1
	canvas.clear_drawing()
	status.text = "Spawned! HP %d | %d RPM" % [stats.max_hp, stats.rpm()]

func _on_clear() -> void:
	canvas.clear_drawing()
	for t in tops.get_children():
		t.queue_free()
	_spawn_count = 0
	status.text = "Cleared. Draw a new shape."
