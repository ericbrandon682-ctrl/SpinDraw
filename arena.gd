class_name Arena
extends StaticBody2D

const RADIUS := 380.0
const WALL_THICKNESS := 80.0
const BOUNCE := 0.4

# Bumpers
const BUMPER_RADIUS := 24.0
const BUMPER_DIST := 0.5            # fraction of RADIUS from center

# Energy zone
const ZONE_RADIUS := 70.0
const ZONE_CHARGE := 0.05           # ult charge per second inside
const ZONE_SPIN := 0.1              # spin ratio recovered per second inside

# Heal orbs
const ORB_INTERVAL := 10.0
const ORB_LIFETIME := 8.0
const ORB_RADIUS := 16.0
const ORB_HEAL := 0.12              # fraction of max HP

# Danger ring
const DANGER_START := 45.0          # seconds into the match
const DANGER_END := 85.0            # ring reaches its smallest size
const SAFE_MIN := 120.0
const DANGER_PERCENT := 0.02        # of max HP per tick
const DANGER_TICK := 0.5

var bumper_positions: Array[Vector2] = []
var orbs: Array = []                # {"node": Node2D, "life": float}
var orb_timer := ORB_INTERVAL
var danger_timer := 0.0
var zone_fx: Polygon2D
var danger_ring: Line2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = BOUNCE
	mat.friction = 0.0
	physics_material_override = mat
	_build_walls()
	_build_visuals()
	_build_bumpers()
	_build_zone()
	_build_danger_ring()

func _vertex(i: int) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(60.0 * i)) * RADIUS

func _apothem() -> float:
	return RADIUS * cos(deg_to_rad(30.0))

func _circle(radius: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.RIGHT.rotated(TAU * i / n) * radius)
	return pts

# ---------- Build ----------

func _build_walls() -> void:
	var apothem := _apothem()
	for i in 6:
		var angle := deg_to_rad(60.0 * i + 30.0)
		var dir := Vector2.RIGHT.rotated(angle)
		var rect := RectangleShape2D.new()
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

func _build_bumpers() -> void:
	for deg in [90.0, 210.0, 330.0]:
		var pos := Vector2.RIGHT.rotated(deg_to_rad(deg)) * RADIUS * BUMPER_DIST
		bumper_positions.append(pos)
		var b := StaticBody2D.new()
		b.collision_layer = 1
		b.collision_mask = 0
		b.position = pos
		var m := PhysicsMaterial.new()
		m.bounce = 1.0
		m.friction = 0.0
		b.physics_material_override = m
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = BUMPER_RADIUS
		cs.shape = circle
		b.add_child(cs)
		var poly := Polygon2D.new()
		poly.polygon = _circle(BUMPER_RADIUS)
		poly.color = Color("d9a82f")
		b.add_child(poly)
		var ring := Line2D.new()
		ring.points = _circle(BUMPER_RADIUS)
		ring.closed = true
		ring.width = 4.0
		ring.default_color = Color("fff2b0")
		b.add_child(ring)
		add_child(b)

func _build_zone() -> void:
	zone_fx = Polygon2D.new()
	zone_fx.polygon = _circle(ZONE_RADIUS, 48)
	zone_fx.color = Color(0.3, 0.8, 0.9, 0.2)
	zone_fx.z_index = 0
	add_child(zone_fx)
	var ring := Line2D.new()
	ring.points = _circle(ZONE_RADIUS, 48)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(0.3, 0.8, 0.9, 0.5)
	zone_fx.add_child(ring)

func _build_danger_ring() -> void:
	danger_ring = Line2D.new()
	danger_ring.closed = true
	danger_ring.width = 6.0
	danger_ring.default_color = Color("ff4d4d")
	danger_ring.z_index = 5
	danger_ring.visible = false
	add_child(danger_ring)

# ---------- Fight logic (called from battle.gd) ----------

func reset() -> void:
	for o in orbs:
		o["node"].queue_free()
	orbs.clear()
	orb_timer = ORB_INTERVAL
	danger_timer = 0.0
	danger_ring.visible = false

func update_fight(delta: float, tops: Array, elapsed: float) -> void:
	var live: Array = []
	for t in tops:
		if t != null and is_instance_valid(t) and not t.dead:
			live.append(t)
	_update_zone(delta, live)
	_update_orbs(delta, live)
	_update_danger(delta, live, elapsed)

func _update_zone(delta: float, live: Array) -> void:
	var occupied := false
	for t in live:
		if t.global_position.distance_to(global_position) < ZONE_RADIUS:
			occupied = true
			if not t.ult_used:
				t.ult_charge = minf(t.ult_charge + ZONE_CHARGE * delta, 1.0)
			t.spin_ratio = minf(t.spin_ratio + ZONE_SPIN * delta, 1.0)
	zone_fx.color.a = 0.4 if occupied else 0.2

func _update_orbs(delta: float, live: Array) -> void:
	orb_timer -= delta
	if orb_timer <= 0.0:
		orb_timer = ORB_INTERVAL
		_spawn_orb()
	for i in range(orbs.size() - 1, -1, -1):
		var o: Dictionary = orbs[i]
		o["life"] -= delta
		var taken := false
		for t in live:
			if t.global_position.distance_to(o["node"].global_position) < ORB_RADIUS + t.body_radius:
				t.heal(int(t.stats.max_hp * ORB_HEAL))
				taken = true
				break
		if taken or o["life"] <= 0.0:
			o["node"].queue_free()
			orbs.remove_at(i)

func _spawn_orb() -> void:
	var pos := Vector2.ZERO
	for attempt in 12:
		var ang := randf() * TAU
		var dist := randf_range(80.0, _apothem() * 0.75)
		pos = Vector2.RIGHT.rotated(ang) * dist
		var ok := true
		for b in bumper_positions:
			if pos.distance_to(b) < BUMPER_RADIUS + 50.0:
				ok = false
		if ok:
			break
	var node := Node2D.new()
	node.position = pos
	var poly := Polygon2D.new()
	poly.polygon = _circle(ORB_RADIUS, 20)
	poly.color = Color("2fbf71")
	node.add_child(poly)
	var ring := Line2D.new()
	ring.points = _circle(ORB_RADIUS + 5.0, 20)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(0.7, 1.0, 0.8, 0.7)
	node.add_child(ring)
	add_child(node)
	orbs.append({"node": node, "life": ORB_LIFETIME})

func _safe_radius(elapsed: float) -> float:
	var t := clampf((elapsed - DANGER_START) / (DANGER_END - DANGER_START), 0.0, 1.0)
	return lerpf(_apothem() - 6.0, SAFE_MIN, t)

func _update_danger(delta: float, live: Array, elapsed: float) -> void:
	if elapsed < DANGER_START:
		danger_ring.visible = false
		return
	var safe := _safe_radius(elapsed)
	danger_ring.visible = true
	danger_ring.points = _circle(safe, 64)
	danger_ring.modulate.a = 0.6 + 0.4 * sin(elapsed * 6.0)
	danger_timer += delta
	if danger_timer < DANGER_TICK:
		return
	danger_timer = 0.0
	for t in live:
		if t.global_position.distance_to(global_position) > safe:
			t.take_damage(maxi(int(t.stats.max_hp * DANGER_PERCENT), 1))
