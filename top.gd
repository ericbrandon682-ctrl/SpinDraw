class_name Top
extends RigidBody2D

signal hp_changed(hp: int, max_hp: int)
signal died

enum Archetype { ATTACK, SPEED, DEFENSE }

const LINE_WIDTH := 4.0
const HALF_THICKNESS := 2.5
const SIMPLIFY_TOLERANCE := 1.0
const MAX_SEGMENTS := 100
const MAX_BLADE_SEGMENTS := 24

# Attack knockback
const KNOCKBACK := 0.9
const KNOCKBACK_COOLDOWN := 0.4

# Spin
const PREVIEW_SPIN := 3.0
const SPIN_DECAY := 0.01
const SPIN_HIT_LOSS := 0.03
const MIN_SPIN_RATIO := 0.5
const SPIN_RECOVERY := 4.0

# Stuck detection
const STUCK_TIME := 1.0
const STUCK_SPEED := 25.0

# Damage tuning
const BODY_DAMAGE := 0.004            # relative speed * mass * this
const BODY_HIT_COOLDOWN := 0.3
const BLADE_DAMAGE := 5
const BLADE_COOLDOWN := 0.35
const THREE_BLADE_COOLDOWN := 0.22
const HEAVY_COOLDOWN := 0.5
const MAX_BULLETS := 12

# Status tuning
const SLOW_TIME := 2.5
const SLOW_SPEED := 0.5
const SLOW_SPIN := 0.6
const BURN_TIME := 4.0
const BURN_DAMAGE := 4                # per second

var stats: TopStats
var hp: int
var dead := false

var archetype := Archetype.ATTACK
var target: Top = null
var arena_center := Vector2.ZERO
var ai_active := false

var spin_ratio := 1.0
var body_radius := 10.0
var _impulse_timer := 0.0
var _kb_cd := 0.0
var _body_cd := 0.0
var _stuck_time := 0.0

# Weapon
var weapon_type := WeaponDefs.Type.NONE
var weapon_color := Color.WHITE
var hitbox: Area2D = null
var bullet_strokes: Array = []
var bullet_radius := 8.0
var bullet_damage := 10
var fire_interval := 1.5
var _fire_timer := 0.0
var _spiral_angle := 0.0
var _melee_cd := 0.0

# Status effects
var slow_time := 0.0
var burn_time := 0.0
var _burn_tick := 0.0

## Call BEFORE add_child. Points are centroid-relative and already battle-scaled.
## weapon = {} or {"type": int, "strokes": Array} (also centroid-relative, scaled).
func setup(strokes_local: Array, p_stats: TopStats, color: Color, weapon: Dictionary = {}) -> void:
	stats = p_stats
	hp = stats.max_hp

	mass = stats.mass
	gravity_scale = 0.0
	linear_damp = 0.4
	angular_damp = 0.05
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 6
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO
	angular_velocity = stats.spin_speed

	# Layers: 1 = walls, 2 = tops, 3 = projectiles
	collision_layer = 2
	collision_mask = 3

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 0.3
	physics_material_override = mat

	var segments := 0
	for s in strokes_local:
		segments = _add_capsules(self, s, segments, MAX_SEGMENTS, HALF_THICKNESS)
		_add_stroke_visual(s, color, LINE_WIDTH)
		for p in s:
			body_radius = maxf(body_radius, p.length())

	_setup_weapon(weapon, color)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_archetype(a: Archetype, p_target: Top, center: Vector2) -> void:
	archetype = a
	target = p_target
	arena_center = center
	match a:
		Archetype.ATTACK:
			mass *= 1.5
			linear_damp = 0.15
		Archetype.SPEED:
			linear_damp = 0.2
		Archetype.DEFENSE:
			mass *= 2.0
			linear_damp = 2.0

# ---------- Building shapes ----------

## Adds capsule colliders along a stroke to `parent`. Returns the new segment count.
func _add_capsules(parent: Node, stroke: PackedVector2Array, count: int,
		limit: int, radius: float) -> int:
	var pts := ShapeUtils.simplify(stroke, SIMPLIFY_TOLERANCE)
	for i in range(pts.size() - 1):
		if count >= limit:
			return count
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 0.5:
			continue
		var cap := CapsuleShape2D.new()
		cap.radius = radius
		cap.height = length + radius * 2.0
		var cs := CollisionShape2D.new()
		cs.shape = cap
		cs.position = (a + b) * 0.5
		cs.rotation = (b - a).angle() - PI * 0.5
		parent.add_child(cs)
		count += 1
	return count

func _add_stroke_visual(stroke: PackedVector2Array, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = stroke
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	add_child(line)

func _setup_weapon(weapon: Dictionary, color: Color) -> void:
	var wstrokes: Array = weapon.get("strokes", [])
	weapon_type = int(weapon.get("type", WeaponDefs.Type.NONE))
	if wstrokes.is_empty():
		weapon_type = WeaponDefs.Type.NONE
		return
	weapon_color = color.lightened(0.5)
	if WeaponDefs.is_melee(weapon_type):
		_build_melee(wstrokes)
	elif WeaponDefs.is_projectile(weapon_type):
		_build_projectile(wstrokes)

func _build_melee(wstrokes: Array) -> void:
	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	add_child(hitbox)
	var copies := 3 if weapon_type == WeaponDefs.Type.THREE_BLADES else 1
	for c in copies:
		var ang := TAU * c / copies
		var phys := 0
		var hit := 0
		for s in wstrokes:
			var rs := PackedVector2Array()
			for p in s:
				rs.append(p.rotated(ang))
			_add_stroke_visual(rs, weapon_color, LINE_WIDTH + 1.0)
			phys = _add_capsules(self, rs, phys, MAX_BLADE_SEGMENTS, HALF_THICKNESS)
			hit = _add_capsules(hitbox, rs, hit, MAX_BLADE_SEGMENTS, HALF_THICKNESS + 3.0)
			for p in rs:
				body_radius = maxf(body_radius, p.length())

func _build_projectile(wstrokes: Array) -> void:
	# Launcher mark on the top (visual only)
	for s in wstrokes:
		_add_stroke_visual(s, weapon_color, LINE_WIDTH)

	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for s in wstrokes:
		for p in s:
			mn = mn.min(p)
			mx = mx.max(p)
	var c := (mn + mx) * 0.5
	var raw := 1.0
	for s in wstrokes:
		for p in s:
			raw = maxf(raw, (p - c).length())
	var r := clampf(raw * 0.5, 6.0, 18.0)
	var f := r / raw
	bullet_strokes = []
	for s in wstrokes:
		var o := PackedVector2Array()
		for p in s:
			o.append((p - c) * f)
		bullet_strokes.append(o)
	bullet_radius = r
	var t := inverse_lerp(6.0, 18.0, r)
	bullet_damage = int(lerpf(8.0, 22.0, t))   # bigger bullet = harder hit
	fire_interval = lerpf(1.2, 1.8, t)         # ...but slower fire

# ---------- Control ----------

func hold() -> void:
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	ai_active = false

func launch(dir: Vector2, power: float) -> void:
	freeze = false
	spin_ratio = 1.0
	angular_velocity = PREVIEW_SPIN
	linear_velocity = dir * stats.max_speed * lerpf(0.4, 1.0, power)
	_fire_timer = 0.8
	ai_active = true

func stop() -> void:
	ai_active = false

# ---------- Physics loop ----------

func _physics_process(delta: float) -> void:
	if not ai_active or freeze or dead:
		return
	_kb_cd = maxf(_kb_cd - delta, 0.0)
	_body_cd = maxf(_body_cd - delta, 0.0)
	_update_spin(delta)
	match archetype:
		Archetype.SPEED:
			_ai_speed(delta)
		Archetype.DEFENSE:
			_ai_defense()
	_update_status(delta)
	_melee_tick(delta)
	_fire_tick(delta)
	_check_stuck(delta)

# ---------- Spin ----------

func _target_spin() -> float:
	var s := stats.spin_speed * spin_ratio
	if slow_time > 0.0:
		s *= SLOW_SPIN
	return s

func _update_spin(delta: float) -> void:
	spin_ratio = maxf(spin_ratio - SPIN_DECAY * delta, MIN_SPIN_RATIO)
	angular_velocity = move_toward(angular_velocity, _target_spin(),
			stats.spin_speed * SPIN_RECOVERY * delta)

## Walls must never disturb the spin.
func _integrate_forces(phys: PhysicsDirectBodyState2D) -> void:
	if not ai_active:
		return
	for i in phys.get_contact_count():
		var other := phys.get_contact_collider_object(i)
		if not (other is Top):
			phys.angular_velocity = _target_spin()
			return

# ---------- Collisions and damage ----------

func _on_body_entered(body: Node) -> void:
	if not ai_active or not (body is Top):
		return
	var other: Top = body
	spin_ratio = maxf(spin_ratio - SPIN_HIT_LOSS, MIN_SPIN_RATIO)

	if archetype == Archetype.ATTACK and _kb_cd <= 0.0:
		_kb_cd = KNOCKBACK_COOLDOWN
		var dir := (other.global_position - global_position).normalized()
		other.apply_central_impulse(dir * mass * stats.max_speed * KNOCKBACK)

	if _body_cd <= 0.0 and not other.dead:
		_body_cd = BODY_HIT_COOLDOWN
		var rel := (linear_velocity - other.linear_velocity).length()
		other.take_damage(int(clampf(rel * mass * BODY_DAMAGE, 1.0, 25.0)))

func _melee_tick(delta: float) -> void:
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	if hitbox == null or _melee_cd > 0.0:
		return
	for b in hitbox.get_overlapping_bodies():
		if not (b is Top) or b == self or b.dead:
			continue
		var dir: Vector2 = (b.global_position - global_position).normalized()
		var dmg := BLADE_DAMAGE
		match weapon_type:
			WeaponDefs.Type.THREE_BLADES:
				_melee_cd = THREE_BLADE_COOLDOWN
			WeaponDefs.Type.HEAVY_HITTER:
				_melee_cd = HEAVY_COOLDOWN
				dmg = int(BLADE_DAMAGE * (1.0 + mass * 0.35))
				b.apply_central_impulse(dir * mass * stats.max_speed * 0.8)
			WeaponDefs.Type.SLOW_EFFECT:
				_melee_cd = BLADE_COOLDOWN
				b.apply_slow()
		b.take_damage(dmg)
		return

func _fire_tick(delta: float) -> void:
	if bullet_strokes.is_empty():
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_interval
	var alive := 0
	for b in get_tree().get_nodes_in_group("bullets"):
		if b is Bullet and b.owner_top == self:
			alive += 1
	if alive >= MAX_BULLETS:
		return
	var count := 3 if weapon_type == WeaponDefs.Type.THREE_PROJECTILES else 1
	for i in count:
		var dir := Vector2.RIGHT.rotated(_spiral_angle + TAU * i / count)
		var b := Bullet.new()
		b.setup(self, bullet_strokes, bullet_radius, bullet_damage, dir, weapon_color,
				weapon_type == WeaponDefs.Type.SELF_RICOCHET,
				weapon_type == WeaponDefs.Type.FIRE)
		b.position = global_position + dir * (body_radius + bullet_radius + 6.0)
		get_parent().add_child(b)
	_spiral_angle += 0.9   # rotates every volley = spiral

# ---------- Status effects ----------

func apply_slow() -> void:
	slow_time = SLOW_TIME

func apply_burn() -> void:
	burn_time = BURN_TIME

func _update_status(delta: float) -> void:
	if slow_time > 0.0:
		slow_time -= delta
		linear_velocity = linear_velocity.limit_length(stats.max_speed * SLOW_SPEED)
	if burn_time > 0.0:
		burn_time -= delta
		_burn_tick += delta
		if _burn_tick >= 1.0:
			_burn_tick -= 1.0
			take_damage(BURN_DAMAGE)
	else:
		_burn_tick = 0.0
	var tint := Color.WHITE
	if slow_time > 0.0:
		tint = Color(0.6, 0.8, 1.0)
	if burn_time > 0.0:
		tint = tint * Color(1.0, 0.6, 0.4)
	modulate = tint

# ---------- Movement AI ----------

func _ai_speed(delta: float) -> void:
	var cruise := stats.max_speed * 1.5
	var spd := linear_velocity.length()
	if spd < 30.0:
		linear_velocity = Vector2.RIGHT.rotated(randf() * TAU) * cruise * 0.6
	elif spd < cruise:
		apply_central_force(linear_velocity.normalized() * mass * cruise * 2.0)
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

# ---------- Unstick ----------

func _check_stuck(delta: float) -> void:
	var touching := get_colliding_bodies()
	if touching.is_empty() or linear_velocity.length() > STUCK_SPEED:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= STUCK_TIME:
		_stuck_time = 0.0
		_separate(touching[0])

func _separate(other: Node) -> void:
	var away: Vector2
	if other is Top:
		away = global_position - other.global_position
		if away.length() < 1.0:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		away = away.normalized()
		other.apply_central_impulse(-away * other.mass * other.stats.max_speed * 0.6)
	else:
		away = (arena_center - global_position).normalized()
	apply_central_impulse(away * mass * stats.max_speed * 0.6)

func take_damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, stats.max_hp)
	if hp == 0:
		dead = true
		died.emit()
