extends Node

const SAVE_PATH := "user://tops.json"
const MAX_TOPS := 8

## Each entry: {"area": float, "color": Color, "strokes": Array of PackedVector2Array}
var tops: Array = []

func _ready() -> void:
	load_tops()

func add_top(area: float, color: Color, strokes: Array) -> bool:
	if tops.size() >= MAX_TOPS:
		return false
	tops.append({"area": area, "color": color, "strokes": strokes.duplicate()})
	save_tops()
	return true

func remove_top(index: int) -> void:
	if index >= 0 and index < tops.size():
		tops.remove_at(index)
		save_tops()

func save_tops() -> void:
	var out := []
	for t in tops:
		var strokes_out := []
		for s in t["strokes"]:
			var arr := []
			for p in s:
				arr.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
			strokes_out.append(arr)
		out.append({"area": t["area"], "color": t["color"].to_html(), "strokes": strokes_out})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))

func load_tops() -> void:
	tops.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		return
	for d in data:
		var strokes: Array = []
		for s in d["strokes"]:
			var pts := PackedVector2Array()
			for p in s:
				pts.append(Vector2(p[0], p[1]))
			strokes.append(pts)
		tops.append({"area": float(d["area"]), "color": Color(d["color"]), "strokes": strokes})
