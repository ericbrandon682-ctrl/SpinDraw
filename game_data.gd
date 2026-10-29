extends Node

const SAVE_PATH := "user://tops.json"
const MAX_TOPS := 8

## Entry: {"area", "color", "strokes", "weapon": {} or {"type": int, "strokes": Array}}
var tops: Array = []

func _ready() -> void:
	load_tops()

func add_top(area: float, color: Color, strokes: Array, weapon: Dictionary = {}, p_name: String = "") -> bool:
	if tops.size() >= MAX_TOPS:
		return false
	tops.append({"area": area, "color": color, "strokes": strokes.duplicate(),
			"weapon": weapon.duplicate(), "name": p_name})
	save_tops()
	return true

func remove_top(index: int) -> void:
	if index >= 0 and index < tops.size():
		tops.remove_at(index)
		save_tops()

func _strokes_to_json(strokes: Array) -> Array:
	var out := []
	for s in strokes:
		var arr := []
		for p in s:
			arr.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
		out.append(arr)
	return out

func _strokes_from_json(data: Array) -> Array:
	var strokes: Array = []
	for s in data:
		var pts := PackedVector2Array()
		for p in s:
			pts.append(Vector2(p[0], p[1]))
		strokes.append(pts)
	return strokes

func save_tops() -> void:
	var out := []
	for t in tops:
		var entry := {
			"area": t["area"],
			"color": t["color"].to_html(),
			"strokes": _strokes_to_json(t["strokes"]),
			"weapon": null,
			"name": t.get("name", ""),
		}
		var w: Dictionary = t.get("weapon", {})
		if not w.is_empty():
			entry["weapon"] = {"type": w["type"], "strokes": _strokes_to_json(w["strokes"])}
		out.append(entry)
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
		var weapon := {}
		var w = d.get("weapon")
		if typeof(w) == TYPE_DICTIONARY:
			weapon = {"type": int(w["type"]), "strokes": _strokes_from_json(w["strokes"])}
		tops.append({
			"area": float(d["area"]),
			"color": Color(d["color"]),
			"strokes": _strokes_from_json(d["strokes"]),
			"weapon": weapon,
			"name": str(d.get("name", "")),
		})
