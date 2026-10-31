class_name Bullet
extends RigidBody2D

const SPEED := 500.0
const MAX_BOUNCES := 1            # normal projectiles
const RICOCHET_MAX_BOUNCES := 6   # Self-Ricochet
const LIFETIME := 8.0

var owner_top: Top
var damage := 10
var speed := SPEED
var bounces := 0
var life := LIFETIME
var ricochet := false
var burn := false
var absorbed := false
var burn_dps := 4

## Strokes are already centered on (0,0) and battle-sized.
func setup(p_owner: Top, strokes: Array, radius: float, dmg: int, dir: Vector2,
		color: Color, is_ricochet: bool, is_burn: bool) -> void:
	owner_top = p_owner
	damage = dmg
	ricochet = is_ricochet
	burn = is_burn
	add_to_group("bullets")

	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	collision_layer = 4   # layer 3 = projectiles
	collision_mask = 1    # bounces off walls only
	contact_monitor = true
	max_contacts_reported = 4
	var mat := PhysicsMaterial.new()
	mat.bounce = 1.0
	mat.friction = 0.0
	physics_material_override = mat
	linear_velocity = dir * speed
	angular_velocity = 6.0

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)

	# Hit detection against tops (bullets never push tops around)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape2D.new()
	var ac := CircleShape2D.new()
	ac.radius = radius + 2.0
	acs.shape = ac
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_hit)
	body_entered.connect(_on_wall)

	var col := Color("ff9a3c") if burn else color
	for s in strokes:
		var line := Line2D.new()
		line.points = s
		line.width = 4.0
		line.default_color = col
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = false
		add_child(line)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# Keep a constant speed so bounces never lose energy
	if linear_velocity.length() > 1.0:
		linear_velocity = linear_velocity.normalized() * speed

func _on_wall(_body: Node) -> void:
	bounces += 1
	var limit := RICOCHET_MAX_BOUNCES if ricochet else MAX_BOUNCES
	if bounces > limit:
		queue_free()

func _on_hit(body: Node) -> void:
	if not (body is Top):
		return
	var t: Top = body
	if t.dead:
		return
	if t == owner_top:
		# Self-Ricochet: after a bounce, hitting its owner absorbs energy
		if ricochet and bounces > 0 and not absorbed and is_instance_valid(owner_top.target):
			absorbed = true
			damage *= 2
			speed *= 1.3
			modulate = Color(1.0, 0.9, 0.3)
			linear_velocity = (owner_top.target.global_position - global_position).normalized() * speed
		return
	t.take_damage(damage)
	if burn:
		t.apply_burn(burn_dps)
	queue_free()
