class_name Arena
extends StaticBody2D

const RADIUS := 380.0
const WALL_THICKNESS := 80.0
const BOUNCE := 0.4

const BUMPER_RADIUS := 24.0
const BUMPER_DIST := 0.5

const ZONE_RADIUS := 70.0
const ZONE_CHARGE := 0.05
const ZONE_SPIN := 0.1

const ORB_INTERVAL := 10.0
const ORB_LIFETIME := 8.0
const ORB_RADIUS := 16.0
const ORB_HEAL := 0.12

const DANGER_START := 45.0
const DANGER_END := 85.0
const SAFE_MIN := 120.0
const DANGER_PERCENT := 0.02
const DANGER_TICK := 0.5

const TILE := 40.0
const BRICK := Color("5c3b2e")
const FLOOR_A := Color("3d4d73")
const FLOOR_B := Color("364466")
const FLOOR_LIGHT := Color("5b6d99")

var bumper_positions: Array[Vector2] = []
var orbs: Array = []
var orb_timer := ORB_INTERVAL
var danger_timer := 0.0
var zone_fx: Polygon2D
var danger_ring: Line2D
var torches: Array = []
var _t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.bounce = BOUNCE
	mat.friction = 0.0
	physics_material_override = mat
	_build_walls()
	_build_rim()
	_build_zone()
	_build_bumpers()
	_build_torches()
	_build_danger_ring()

func _process(delta: float) -> void:
	_t += delta
	for i in torches.size():
		var flame: Node2D = torches[i].get_child(1)
		flame.scale = Vector2(1.0, 1.0 + 0.18 * sin(_t * 12.0 + i * 1.7))

func _vertex(i: int) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(60.0 * i)) * RADIUS

func _apothem() -> float:
	return RADIUS * cos(deg_to_rad(30.0))

func _hex(scale_by: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(_vertex(i) * scale_by)
	return pts

func _circle(radius: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.RIGHT.rotated(TAU * i / n) * radius)
	return pts

func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

# ---------- Floor (drawn once) ----------

func _draw() -> void:
	draw_colored_polygon(_hex(), BRICK)
	var inner := _hex((_apothem() - 20.0) / _apothem())
	var n := int(RADIUS / TILE) + 1
	for gx in range(-n, n):
		for gy in range(-n, n):
			var r := Rect2(gx * TILE, gy * TILE, TILE, TILE)
			var ok := true
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				if not Geometry2D.is_point_in_polygon(c, inner):
					ok = false
					break
			if not ok:
				continue
			draw_rect(r, FLOOR_A if posmod(gx + gy, 2) == 0 else FLOOR_B)
			draw_rect(Rect2(r.position, Vector2(TILE, 3)), FLOOR_LIGHT)
			draw_rect(Rect2(r.position, Vector2(3, TILE)), FLOOR_LIGHT)

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

func _build_rim() -> void:
	var dark := Line2D.new()
	dark.points = _hex()
	dark.closed = true
	dark.width = 18.0
	dark.default_color = Color("07070f")
	add_child(dark)
	var gold := Line2D.new()
	gold.points = _hex()
	gold.closed = true
	gold.width = 7.0
	gold.default_color = Color("d9a82f")
	add_child(gold)

func _build_torches() -> void:
	for i in 6:
		var tn := Node2D.new()
		tn.position = _vertex(i) * 0.93
		tn.z_index = 2
		var base := Polygon2D.new()
		base.polygon = _rect(-6, -2, 12, 16)
		base.color = Color("5c3b2e")
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([Vector2(0, -22), Vector2(9, -8), Vector2(0, 0), Vector2(-9, -8)])
		flame.color = Color("ff8a2b")
		var core := Polygon2D.new()
		core.polygon = PackedVector2Array([Vector2(0, -14), Vector2(4, -7), Vector2(0, -2), Vector2(-4, -7)])
		core.color = Color("ffec27")
		tn.add_child(base)
		tn.add_child(flame)   # child index 1 flickers
		tn.add_child(core)
		add_child(tn)
		torches.append(tn)

func _build_bumpers() -> void:
	var R := BUMPER_RADIUS
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
		circle.radius = R
		cs.shape = circle
		b.add_child(cs)
		# Rupee-shaped gem
		var gem := PackedVector2Array([Vector2(0, -R), Vector2(R * 0.8, -R * 0.4),
				Vector2(R * 0.8, R * 0.4), Vector2(0, R), Vector2(-R * 0.8, R * 0.4),
				Vector2(-R * 0.8, -R * 0.4)])
		var poly := Polygon2D.new()
		poly.polygon = gem
		poly.color = Color("3ddc84")
		b.add_child(poly)
		var line := Line2D.new()
		line.points = gem
		line.closed = true
		line.width = 4.0
		line.default_color = Color("07070f")
		b.add_child(line)
		var shine := Polygon2D.new()
		shine.polygon = _rect(-R * 0.45, -R * 0.4, 6, 12)
		shine.color = Color.WHITE
		b.add_child(shine)
		add_child(b)

func _build_zone() -> void:
	zone_fx = Polygon2D.new()
	zone_fx.polygon = _circle(ZONE_RADIUS, 24)
	zone_fx.color = Color(0.3, 0.8, 0.9, 0.2)
	zone_fx.z_index = 0
	add_child(zone_fx)
	var ring := Line2D.new()
	ring.points = _circle(ZONE_RADIUS, 24)
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(0.5, 0.95, 1.0, 0.7)
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
		# Zelda pickups blink before they vanish
		o["node"].visible = not (o["life"] < 2.5 and int(o["life"] * 6.0) % 2 == 0)
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
	node.z_index = 3
	var s := Sprite2D.new()
	s.texture = UiStyle.heart_texture(Color("ff4d6d"))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(5, 5)
	node.add_child(s)
	add_child(node)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", -5.0, 0.4)
	tw.tween_property(s, "position:y", 5.0, 0.4)
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
	danger_ring.points = _circle(safe, 48)
	danger_ring.modulate.a = 0.6 + 0.4 * sin(elapsed * 6.0)
	danger_timer += delta
	if danger_timer < DANGER_TICK:
		return
	danger_timer = 0.0
	for t in live:
		if t.global_position.distance_to(global_position) > safe:
			t.take_damage(maxi(int(t.stats.max_hp * DANGER_PERCENT), 1))
