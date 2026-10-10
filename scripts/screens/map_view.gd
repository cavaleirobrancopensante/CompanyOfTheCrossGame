extends Control
## Draws the peninsula, roads and places; reports taps.

signal node_tapped(idx: int)

var selected := -1
var marker := Vector2(-1, -1)
var pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func to_px(x: float, y: float) -> Vector2:
	var pad := 14.0
	var w := size.x - pad * 2
	var h := size.y - pad * 2
	# Keep a pleasant aspect: the map is taller than wide.
	var scale_w := minf(w, h * 0.82)
	var scale_h := minf(h, w / 0.82)
	var off := Vector2((size.x - scale_w) / 2.0, (size.y - scale_h) / 2.0)
	return off + Vector2(x * scale_w, y * scale_h)


func node_px(i: int) -> Vector2:
	var n: Dictionary = Game.nodes[i]
	return to_px(float(n["x"]), float(n["y"]))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := -1
		var best_d := 48.0
		for i in Game.nodes.size():
			var d := node_px(i).distance_to(event.position)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			node_tapped.emit(best)
			accept_event()


func animate_march(from: int, to: int, done: Callable) -> void:
	marker = node_px(from)
	var tw := create_tween()
	tw.tween_property(self, "marker", node_px(to), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(done)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Sea
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.16, 0.2))
	# Land
	var pts := PackedVector2Array()
	for p in GameData.OUTLINE:
		pts.append(to_px(p.x, p.y))
	draw_colored_polygon(pts, Color(0.36, 0.33, 0.24))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.55, 0.5, 0.36), 3.0, true)
	# Alps
	for i in 9:
		var base := to_px(0.12 + i * 0.075, 0.075 + (i % 2) * 0.012)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-16, 10), base + Vector2(0, -16), base + Vector2(16, 10)]), Color(0.5, 0.48, 0.42))
	var here := Game.current_node
	var here_links: Array = Game.nodes[here]["links"]
	# Roads
	for n in Game.nodes:
		for l in n["links"]:
			if int(l) < int(n["id"]):
				continue
			var a := node_px(int(n["id"]))
			var b := node_px(int(l))
			var active := (int(n["id"]) == here and here_links.has(l)) or (int(l) == here)
			var col := UI.GOLD if active else Color(0.55, 0.48, 0.34, 0.6)
			_dashed(a, b, col, 4.0 if active else 2.5)
	# Places
	var target := -1
	var giver := -1
	if not Game.contract.is_empty():
		target = int(Game.contract["target"])
		giver = int(Game.contract["giver"])
	for n in Game.nodes:
		var i := int(n["id"])
		var p := node_px(i)
		var fcol: Color = GameData.FACTION_COLORS.get(n["faction"], Color.GRAY)
		_draw_place(p, n["kind"], fcol, n["cleared"])
		if i == selected:
			draw_arc(p, 26, 0, TAU, 32, Color.WHITE, 3.0)
		var objective: bool = (i == target and not Game.contract.get("done", false)) or (i == giver and Game.contract.get("done", false))
		if objective:
			var r := 30.0 + sin(pulse * 4.0) * 4.0
			draw_arc(p, r, 0, TAU, 32, UI.BAD, 3.0)
		var fs := 17 if n["kind"] in ["village", "ruins", "camp"] else 20
		var label_pos := p + Vector2(-90, 34)
		draw_string_outline(font, label_pos, n["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(font, label_pos, n["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, fs, UI.PARCHMENT)
	# The company banner
	var bp := marker if marker.x >= 0 else node_px(here)
	_draw_banner(bp + Vector2(0, -6))


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dist := a.distance_to(b)
	var dir := (b - a) / maxf(dist, 0.001)
	var t := 0.0
	while t < dist:
		draw_line(a + dir * t, a + dir * minf(t + 9.0, dist), col, w)
		t += 15.0


func _draw_place(p: Vector2, kind: String, fcol: Color, cleared: bool) -> void:
	match kind:
		"city":
			draw_rect(Rect2(p + Vector2(-14, -10), Vector2(28, 20)), fcol)
			draw_rect(Rect2(p + Vector2(-17, -18), Vector2(8, 28)), fcol.darkened(0.2))
			draw_rect(Rect2(p + Vector2(9, -18), Vector2(8, 28)), fcol.darkened(0.2))
			draw_rect(Rect2(p + Vector2(-17, -18), Vector2(34, 28)), Color.BLACK, false, 2.0)
		"town":
			draw_rect(Rect2(p + Vector2(-11, -9), Vector2(22, 18)), fcol)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -9), p + Vector2(0, -20), p + Vector2(13, -9)]), fcol.darkened(0.3))
		"village":
			draw_circle(p, 9, fcol.darkened(0.15))
			draw_arc(p, 9, 0, TAU, 20, Color.BLACK, 2.0)
		"monastery":
			draw_circle(p, 13, Color(0.92, 0.88, 0.78))
			draw_rect(Rect2(p + Vector2(-2.5, -9), Vector2(5, 18)), UI.RED)
			draw_rect(Rect2(p + Vector2(-7, -4), Vector2(14, 5)), UI.RED)
		"ruins":
			var c := Color(0.45, 0.65, 0.75) if not cleared else Color(0.4, 0.4, 0.4)
			for k in 3:
				draw_rect(Rect2(p + Vector2(-12 + k * 9, -6 - (k % 2) * 8), Vector2(6, 16 + (k % 2) * 8)), c)
		"camp":
			var c := UI.BAD if not cleared else Color(0.4, 0.4, 0.4)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 10), p + Vector2(0, -14), p + Vector2(14, 10)]), c)
			draw_line(p + Vector2(-6, 10), p + Vector2(0, 0), Color.BLACK, 2.0)
			draw_line(p + Vector2(6, 10), p + Vector2(0, 0), Color.BLACK, 2.0)


func _draw_banner(p: Vector2) -> void:
	draw_line(p, p + Vector2(0, -46), Color(0.3, 0.2, 0.1), 4.0)
	var flag := PackedVector2Array([p + Vector2(2, -46), p + Vector2(30, -46), p + Vector2(30, -24), p + Vector2(16, -18), p + Vector2(2, -24)])
	draw_colored_polygon(flag, Color(0.93, 0.89, 0.78))
	draw_rect(Rect2(p + Vector2(14, -44), Vector2(4, 20)), UI.RED)
	draw_rect(Rect2(p + Vector2(8, -38), Vector2(16, 4)), UI.RED)
