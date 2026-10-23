class_name Top
extends RigidBody2D

signal hp_changed(hp: int, max_hp: int)
signal died

var stats: TopStats
var hp: int

## Call BEFORE add_child. Points are already relative to the centroid.
func setup(hull_local: PackedVector2Array, stroke_local: PackedVector2Array,
		p_stats: TopStats, color: Color) -> void:
	stats = p_stats
	hp = stats.max_hp

	mass = stats.mass
	gravity_scale = 0.0
	linear_damp = 0.5
	angular_damp = 0.15
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	# Origin = centroid, so force the center of mass to the local origin.
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO
	angular_velocity = stats.spin_speed

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 0.1
	physics_material_override = mat

	# Hidden physics hull
	var col := CollisionPolygon2D.new()
	col.polygon = hull_local
	add_child(col)

	# Visible player drawing
	var line := Line2D.new()
	line.points = stroke_local
	line.width = 6.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	add_child(line)

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, stats.max_hp)
	if hp == 0:
		died.emit()
