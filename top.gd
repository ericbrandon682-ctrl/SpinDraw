class_name Top
extends RigidBody2D

signal hp_changed(hp: int, max_hp: int)
signal died

enum Archetype { ATTACK, SPEED, DEFENSE }

const LINE_WIDTH := 6.0
const HALF_THICKNESS := 3.5
const SIMPLIFY_TOLERANCE := 1.5
const MAX_SEGMENTS := 100

var stats: TopStats
var hp: int

# Movement AI state
var archetype := Archetype.ATTACK
var target: Top = null
var arena_center := Vector2.ZERO
var ai_active := false
var _impulse_timer := 0.0

## Call BEFORE add_child. Points are centroid-relative and already battle-scaled.
func setup(strokes_local: Array, p_stats: TopStats, color: Color) -> void:
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
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO
	angular_velocity = stats.spin_speed

	# Layers: 1 = walls, 2 = tops, 3 = projectiles (later)
	collision_layer = 2
	collision_mask = 3

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 0.1
	physics_material_override = mat

	var segments := 0
	for s in strokes_local:
		segments = _add_stroke_collision(s, segments)
		_add_stroke_visual(s, color)

## Chooses the movement class. Call after setup().
func set_archetype(a: Archetype, p_target: Top, center: Vector2) -> void:
	archetype = a
	target = p_target
	arena_center = center
	match a:
		Archetype.DEFENSE:
			mass *= 2.0          # heavy anchor: hard to push around
			linear_damp = 2.0    # strong resistance to displacement
		Archetype.SPEED:
			linear_damp = 0.2    # keeps momentum between ricochets

func _add_stroke_collision(stroke: PackedVector2Array, count: int) -> int:
	var pts := ShapeUtils.simplify(stroke, SIMPLIFY_TOLERANCE)
	for i in range(pts.size() - 1):
		if count >= MAX_SEGMENTS:
			return count
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 0.5:
			continue
		var cap := CapsuleShape2D.new()
		cap.radius = HALF_THICKNESS
		cap.height = length + HALF_THICKNESS * 2.0
		var cs := CollisionShape2D.new()
		cs.shape = cap
		cs.position = (a + b) * 0.5
		cs.rotation = (b - a).angle() - PI * 0.5
		add_child(cs)
		count += 1
	return count

func _add_stroke_visual(stroke: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.points = stroke
	line.width = LINE_WIDTH
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	add_child(line)

func hold() -> void:
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	ai_active = false

func launch(dir: Vector2, power: float) -> void:
	freeze = false
	angular_velocity = stats.spin_speed
	linear_velocity = dir * stats.max_speed * lerpf(0.4, 1.0, power)
	ai_active = true

# ---------- Movement AI ----------

func _physics_process(delta: float) -> void:
	if not ai_active or freeze:
		return
	match archetype:
		Archetype.ATTACK:
			_ai_attack()
		Archetype.SPEED:
			_ai_speed(delta)
		Archetype.DEFENSE:
			_ai_defense()

func _ai_attack() -> void:
	if not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	apply_central_force(dir * mass * stats.max_speed * 1.5)
	if linear_velocity.length() > stats.max_speed:
		linear_velocity = linear_velocity.limit_length(stats.max_speed)

func _ai_speed(delta: float) -> void:
	var cruise := stats.max_speed * 1.3
	var spd := linear_velocity.length()
	if spd < 30.0:
		linear_velocity = Vector2.RIGHT.rotated(randf() * TAU) * cruise * 0.6
	elif spd < cruise:
		# Keep moving the way it is going; walls provide the ricochets
		apply_central_force(linear_velocity.normalized() * mass * cruise * 2.0)
	# Random kicks make the path unpredictable
	_impulse_timer -= delta
	if _impulse_timer <= 0.0:
		_impulse_timer = randf_range(0.5, 1.2)
		apply_central_impulse(Vector2.RIGHT.rotated(randf() * TAU) * mass * cruise * 0.5)
	if linear_velocity.length() > cruise * 1.4:
		linear_velocity = linear_velocity.limit_length(cruise * 1.4)

func _ai_defense() -> void:
	var to_center := arena_center - global_position
	var d := to_center.length()
	if d > 25.0:
		apply_central_force(to_center.normalized() * mass * 150.0 * clampf(d / 150.0, 0.2, 1.0))

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, stats.max_hp)
	if hp == 0:
		died.emit()
