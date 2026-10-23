class_name TopStats
extends RefCounted

const MIN_AREA := 8000.0
const MAX_AREA := 350000.0

var area: float
var size_t: float        # 0 = tiny, 1 = huge
var max_hp: int
var mass: float
var max_speed: float     # px/s, used by the Phase 2 movement AI
var spin_speed: float    # rad/s (angular_velocity)

static func from_area(a: float) -> TopStats:
	var s := TopStats.new()
	s.area = a
	s.size_t = clampf(inverse_lerp(MIN_AREA, MAX_AREA, a), 0.0, 1.0)
	var t := s.size_t
	# Big = tanky and heavy but slow. Small = glass cannon, fast and fast-spinning.
	s.max_hp = int(lerpf(40.0, 400.0, t))
	s.mass = lerpf(0.5, 8.0, t)
	s.max_speed = lerpf(700.0, 250.0, t)
	s.spin_speed = lerpf(30.0, 8.0, t)
	return s

func rpm() -> int:
	return int(spin_speed * 60.0 / TAU)
