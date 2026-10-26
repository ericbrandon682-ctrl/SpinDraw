class_name Arena
extends StaticBody2D

const RADIUS := 340.0
const WALL_THICKNESS := 80.0
const BOUNCE := 0.4  # Godot adds this to the top's own bounce (0.5)

func _ready() -> void:
	collision_layer = 1   # layer 1 = walls
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = BOUNCE
	mat.friction = 0.0
	physics_material_override = mat
	_build_walls()
	_build_visuals()

func _vertex(i: int) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(60.0 * i)) * RADIUS

func _build_walls() -> void:
	var apothem := RADIUS * cos(deg_to_rad(30.0))
	for i in 6:
		var angle := deg_to_rad(60.0 * i + 30.0)  # outward normal of this edge
		var dir := Vector2.RIGHT.rotated(angle)
		var rect := RectangleShape2D.new()
		# Longer than the edge so neighbouring walls overlap at the corners
		rect.size = Vector2(RADIUS + WALL_THICKNESS * 2.0, WALL_THICKNESS)
		var cs := CollisionShape2D.new()
		cs.shape = rect
		cs.position = dir * (apothem + WALL_THICKNESS * 0.5)
		cs.rotation = angle + PI * 0.5
		add_child(cs)

func _build_visuals() -> void:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(_vertex(i))
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color("23283a")
	add_child(fill)
	var rim := Line2D.new()
	rim.points = pts
	rim.closed = true
	rim.width = 8.0
	rim.default_color = Color("6c7bd9")
	rim.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(rim)
