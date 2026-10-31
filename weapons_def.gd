class_name WeaponDefs
extends RefCounted

enum Type { NONE, THREE_BLADES, HEAVY_HITTER, SLOW_EFFECT, THREE_PROJECTILES, SELF_RICOCHET, FIRE }

const NAMES := ["No weapon", "3 Blades", "Heavy Hitter", "Slow Effect",
		"3 Projectiles", "Self-Ricochet", "Fire Effect"]

const DESCRIPTIONS := [
	"",
	"Melee: your blade is copied 3x around the top. Rapid hits.",
	"Melee: big damage and knockback, scales with mass.",
	"Melee: hits slow the enemy's speed and spin.",
	"Projectile: 3 bullets in a spiral spray every 1.5s.",
	"Projectile: a bullet that loops back to you gets stronger.",
	"Projectile: hits burn the enemy over time.",
]

static func is_melee(t: int) -> bool:
	return t >= Type.THREE_BLADES and t <= Type.SLOW_EFFECT

static func is_projectile(t: int) -> bool:
	return t >= Type.THREE_PROJECTILES
