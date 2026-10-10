extends Control
## First-person view of the same battle the tactical view shows.
## Fake 3D in 2D, the same trick as the mech game: the field is flat, so every man,
## corpse and bolt is a sprite drawn in code, scaled by distance and sorted far to near.
## Left thumb walks, right thumb looks, buttons swing/shoot/rally/switch view.

const EYE := 13.2          ## eye height in world px (8 px = 1 m)
const MAN_H := 14.4
const LOOK_SENS := 0.006
const PITCH_SENS := 0.8
const PITCH_LIMIT := 0.35
const JOY_RADIUS := 90.0
const SKY_TOP := Color(0.33, 0.47, 0.66)
const SKY_LOW := Color(0.86, 0.8, 0.66)
const HAZE := Color(0.62, 0.64, 0.52)
const GROUND_FAR := Color(0.36, 0.42, 0.25)
const GROUND_NEAR := Color(0.23, 0.29, 0.14)

var battle  # battle_screen.gd (untyped to avoid a preload cycle)
var pitch := 0.0
var move_touch := -1
var move_origin := Vector2()
var look_touch := -1
var look_last := Vector2()
var swing_touch := -1
var ridge_far := PackedFloat32Array()
var ridge_near := PackedFloat32Array()
var font: Font

# set during _draw
var _w := 0.0
var _h := 0.0
var _horizon := 0.0
var _focal := 1.0
var _cam := Vector2()
var _dir := Vector2.RIGHT
var _right := Vector2.DOWN
var _bob := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 2987
	ridge_far.resize(256)
	ridge_near.resize(256)
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	for i in 256:
		var a := float(i) / 256.0 * TAU
		ridge_far[i] = 34.0 + 20.0 * sin(a * 3.0 + ph[0]) + 10.0 * sin(a * 7.0 + ph[1]) + 5.0 * sin(a * 17.0 + ph[2])
		ridge_near[i] = maxf(4.0, 12.0 + 7.0 * sin(a * 11.0 + ph[3]) + 5.0 * sin(a * 29.0 + ph[0]) + 3.0 * sin(a * 53.0 + ph[1]))


func _process(_delta: float) -> void:
	if not visible or battle == null:
		return
	var h: Dictionary = battle.hero
	if h.is_empty():
		return
	# Keyboard for testing on a PC.
	var mv := Vector2.ZERO
	if move_touch < 0:
		if Input.is_physical_key_pressed(KEY_W): mv.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): mv.y += 1.0
		if Input.is_physical_key_pressed(KEY_A): mv.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): mv.x += 1.0
		h["move"] = mv
		h["run"] = Input.is_physical_key_pressed(KEY_SHIFT)
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT): turn -= 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_RIGHT): turn += 1.0
	h["angle"] = wrapf(float(h["angle"]) + turn * 2.4 * get_process_delta_time(), -PI, PI)
	if swing_touch >= 0 or Input.is_physical_key_pressed(KEY_SPACE):
		battle.hero_swing()


# ---------------------------------------------------------------- input

func _swing_center() -> Vector2:
	return Vector2(size.x - 120.0, size.y - 130.0)


func _shoot_center() -> Vector2:
	return Vector2(size.x - 265.0, size.y - 85.0)


func _tactical_rect() -> Rect2:
	return Rect2(size.x - 210.0, 14.0, 196.0, 64.0)


func _rally_rect() -> Rect2:
	return Rect2(size.x - 210.0, 88.0, 196.0, 58.0)


func _input(event: InputEvent) -> void:
	if not visible or battle == null:
		return
	var h: Dictionary = battle.hero
	if h.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			battle.hero_shoot()
		elif event.keycode in [KEY_TAB, KEY_V]:
			battle.toggle_fps()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			battle.rally_to_hero()
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			get_viewport().set_input_as_handled()
			if _tactical_rect().grow(10).has_point(p):
				_release_all()
				battle.toggle_fps()
				return
			if _rally_rect().grow(8).has_point(p):
				battle.rally_to_hero()
				return
			if p.distance_to(_swing_center()) < 95.0:
				swing_touch = event.index
				battle.hero_swing()
				return
			if h["c"].get("missile", "") != "" and p.distance_to(_shoot_center()) < 64.0:
				battle.hero_shoot()
				return
			if p.x < size.x * 0.45:
				if move_touch < 0:
					move_touch = event.index
					move_origin = p
					h["move"] = Vector2.ZERO
			elif look_touch < 0:
				look_touch = event.index
				look_last = p
		else:
			if event.index == move_touch:
				move_touch = -1
				h["move"] = Vector2.ZERO
				h["run"] = false
			if event.index == look_touch:
				look_touch = -1
			if event.index == swing_touch:
				swing_touch = -1
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if event.index == move_touch:
			var v: Vector2 = (event.position - move_origin) / JOY_RADIUS
			h["move"] = v.limit_length(1.0) if v.length() > 0.12 else Vector2.ZERO
			h["run"] = v.length() > 0.9
		elif event.index == look_touch or event.index == swing_touch:
			var f := 1.0 if event.index == look_touch else 0.6
			h["angle"] = wrapf(float(h["angle"]) + event.relative.x * LOOK_SENS * f, -PI, PI)
			pitch = clampf(pitch - event.relative.y * PITCH_SENS * f, -size.y * PITCH_LIMIT, size.y * PITCH_LIMIT)


func _release_all() -> void:
	move_touch = -1
	look_touch = -1
	swing_touch = -1
	if battle and not battle.hero.is_empty():
		battle.hero["move"] = Vector2.ZERO


# ---------------------------------------------------------------- projection

## Returns Vector3(screen x, screen y, depth) of a world point at height z; depth <= 0 is behind.
func _project(p: Vector2, z: float) -> Vector3:
	var rel := p - _cam
	var ty := _dir.dot(rel)
	if ty < 2.0:
		return Vector3(0, 0, -1)
	var tx := _right.dot(rel)
	return Vector3(_w * 0.5 + tx / ty * _focal, _horizon + (EYE + _bob - z) / ty * _focal, ty)


func _fog(c: Color, depth: float) -> Color:
	return c.lerp(HAZE, clampf(depth / 900.0, 0.0, 0.75))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if battle == null or battle.hero.is_empty():
		return
	var hero: Dictionary = battle.hero
	_w = size.x
	_h = size.y
	_focal = maxf(_w * 0.5 / 0.78, _h * 0.5 / 0.62)
	_horizon = _h * 0.46 + pitch
	_cam = hero["pos"]
	_dir = Vector2.from_angle(float(hero["angle"]))
	_right = Vector2(-_dir.y, _dir.x)
	var moving: float = hero["move"].length()
	_bob = sin(battle.time * (11.0 if hero["run"] else 8.0)) * 0.5 * moving

	_draw_sky()
	_draw_ground()
	_draw_sprites()
	_draw_hands(hero)
	_draw_hud(hero)


func _sky_x(rel: float) -> float:
	return _w * 0.5 + tan(rel) * _focal


func _draw_sky() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, -10), Vector2(_w, -10), Vector2(_w, _horizon), Vector2(0, _horizon)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	if _horizon < -10:
		return
	# Distant hills, then the tree line, wrapped around the whole horizon.
	var ang := float(battle.hero["angle"])
	for layer in 2:
		var arr := ridge_far if layer == 0 else ridge_near
		var col := Color(0.52, 0.56, 0.6) if layer == 0 else Color(0.24, 0.3, 0.2)
		var pts := PackedVector2Array()
		pts.append(Vector2(0, _horizon + 1))
		var step := 10.0
		var x := 0.0
		while x <= _w + step:
			var rel := atan((x - _w * 0.5) / _focal)
			var a := wrapf(ang + rel, 0.0, TAU)
			var idx := int(a / TAU * 256.0) % 256
			var hgt: float = arr[idx] * (_h / 720.0)
			pts.append(Vector2(x, _horizon - hgt))
			x += step
		pts.append(Vector2(_w + step, _horizon + 1))
		draw_colored_polygon(pts, col)


func _draw_ground() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, _horizon), Vector2(_w, _horizon), Vector2(_w, _h + 10), Vector2(0, _h + 10)]),
		PackedColorArray([GROUND_FAR, GROUND_FAR, GROUND_NEAR, GROUND_NEAR]))
	# Patches of grass and earth, laid flat on the ground.
	var patches := []
	for d in battle.decor:
		var pr := _project(d["p"], 0.0)
		if pr.z <= 0 or pr.z > 1100:
			continue
		var rx := float(d["r"]) / pr.z * _focal
		if pr.x + rx < 0 or pr.x - rx > _w:
			continue
		patches.append([pr, rx, d])
	patches.sort_custom(func(a, b): return a[0].z > b[0].z)
	for item in patches:
		var pr: Vector3 = item[0]
		var rx: float = item[1]
		var d: Dictionary = item[2]
		var ry := rx * clampf((EYE + _bob) / pr.z, 0.02, 1.0)
		var col := Color(0.24, 0.3, 0.16) if d["k"] == 0 else (Color(0.33, 0.38, 0.21) if d["k"] == 1 else Color(0.33, 0.29, 0.2))
		_ellipse(Vector2(pr.x, pr.y), rx, ry, _fog(col, pr.z))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var t := TAU * i / 12.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_colored_polygon(pts, col)


func _draw_sprites() -> void:
	var list := []
	# Fallen men.
	for c in battle.corpses:
		var pr := _project(c["p"], 0.0)
		if pr.z > 0 and pr.z < 700:
			list.append({"k": "corpse", "pr": pr, "team": c["team"], "a": c["a"]})
	# Every man in every squad still on the field.
	for ui in battle.units.size():
		var u: Dictionary = battle.units[ui]
		if u["state"] != "ok" and u["state"] != "rout":
			continue
		var men: Array = battle.formation(u)
		for mi in men.size():
			var jitter := Vector2(sin(mi * 12.9898 + ui * 3.1) * 2.0, cos(mi * 78.233 + ui) * 2.0)
			var pr := _project(men[mi] + jitter, 0.0)
			if pr.z < 9.0 or pr.z > 1300:
				continue  # too close: you are shoulder to shoulder with him
			if pr.x < -80 or pr.x > _w + 80:
				continue
			list.append({"k": "man", "pr": pr, "u": u, "i": mi})
	# Bolts and arrows in flight.
	for p in battle.projectiles:
		if p["t"] < 0:
			continue
		var t := clampf(float(p["t"]), 0.0, 1.0)
		var wp: Vector2 = p["a"].lerp(p["b"], t)
		var z := 12.0 + sin(t * PI) * 30.0
		var pr := _project(wp, z)
		if pr.z > 0:
			var pr2 := _project(p["a"].lerp(p["b"], maxf(0.0, t - 0.04)), 12.0 + sin(maxf(0.0, t - 0.04) * PI) * 30.0)
			list.append({"k": "bolt", "pr": pr, "pr2": pr2})
	for f in battle.floaters:
		var pr := _project(f["p"], 18.0 + float(f["t"]) * 10.0)
		if pr.z > 0:
			list.append({"k": "text", "pr": pr, "f": f})
	list.sort_custom(func(a, b): return a["pr"].z > b["pr"].z)
	for s in list:
		match s["k"]:
			"corpse":
				_draw_corpse(s["pr"], s["team"], s["a"])
			"man":
				_draw_man(s["pr"], s["u"], s["i"])
			"bolt":
				if s["pr2"].z > 0:
					draw_line(Vector2(s["pr2"].x, s["pr2"].y), Vector2(s["pr"].x, s["pr"].y), Color(0.95, 0.9, 0.75), maxf(1.0, 30.0 / s["pr"].z))
			"text":
				var f: Dictionary = s["f"]
				var pos := Vector2(s["pr"].x - 90, s["pr"].y)
				draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 180, 26, 5, Color.BLACK)
				draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 180, 26, f["col"])


func _draw_corpse(pr: Vector3, team: int, a: float) -> void:
	var k := _focal / pr.z
	var ln := MAN_H * 0.8 * k
	var hgt := maxf(1.0, ln * 0.25 * clampf(EYE / pr.z * 4.0, 0.15, 1.0))
	var col := Color(0.6, 0.55, 0.48) if team == 0 else Color(0.3, 0.24, 0.18)
	var off := cos(a) * ln * 0.5
	draw_rect(Rect2(pr.x - ln * 0.5 + off * 0.3, pr.y - hgt, ln, hgt), _fog(col, pr.z))
	draw_rect(Rect2(pr.x - ln * 0.5 + off * 0.3, pr.y - hgt, ln * 0.12, hgt), _fog(Color(0.45, 0.12, 0.1), pr.z))


func _draw_man(pr: Vector3, u: Dictionary, idx: int) -> void:
	var k := _focal / pr.z
	var H := MAN_H * k
	var x := pr.x
	var y := pr.y
	var unit: Dictionary = u["u"]
	var kit: Dictionary = unit["kit"]
	var team: int = u["team"]
	var d := pr.z
	var moving: bool = u["moving"] or u["state"] == "rout"
	var step := sin(battle.time * 9.0 + idx * 1.7) if moving else 0.0
	var fighting := false
	if u["state"] == "ok":
		var tgt: int = u["target"]
		if tgt >= 0 and tgt < battle.units.size():
			fighting = u["pos"].distance_to(battle.units[tgt]["pos"]) < battle.radius(u) + battle.radius(battle.units[tgt]) + 8.0
	var jab := maxf(0.0, sin(battle.time * 6.0 + idx * 2.3)) if fighting else 0.0
	var tunic: Color
	if team == 0:
		tunic = Color(0.9, 0.86, 0.76)
	else:
		match u["type"]:
			"bowman": tunic = Color(0.38, 0.42, 0.3)
			"zealot": tunic = Color(0.25, 0.42, 0.55)
			"raider": tunic = Color(0.5, 0.36, 0.22)
			_: tunic = Color(0.42, 0.32, 0.24)
	if float(u["flash"]) > 0.0:
		tunic = tunic.lerp(Color(1, 0.3, 0.2), 0.22)
	tunic = _fog(tunic, d)
	var skin := _fog(Color(0.82, 0.62, 0.48), d)
	var steel := _fog(Color(0.7, 0.72, 0.75), d)
	var dark := _fog(Color(0.22, 0.18, 0.14), d)
	var red := _fog(UI.RED, d)

	if H < 5.0:
		draw_rect(Rect2(x - H * 0.15, y - H, H * 0.3, H), tunic)
		return

	var base_y := y
	if unit["cav"]:
		# Horse, side-on.
		var hc := _fog(Color(0.36, 0.24, 0.16) if team == 1 else Color(0.85, 0.82, 0.78), d)
		var bw := H * 0.95
		draw_rect(Rect2(x - bw * 0.5, y - H * 0.85, bw, H * 0.34), hc)
		for li in 4:
			var lx := x - bw * 0.42 + li * bw * 0.28
			var sw := step * H * 0.08 * (1.0 if li % 2 == 0 else -1.0)
			draw_line(Vector2(lx, y - H * 0.52), Vector2(lx + sw, y), hc, maxf(1.0, H * 0.06))
		draw_line(Vector2(x + bw * 0.45, y - H * 0.8), Vector2(x + bw * 0.62, y - H * 1.08), hc, maxf(1.5, H * 0.12))
		if team == 0:
			draw_rect(Rect2(x - bw * 0.3, y - H * 0.86, bw * 0.6, H * 0.2), red)
		base_y = y - H * 0.62
		H *= 0.9
	else:
		var ls := step * H * 0.06
		draw_rect(Rect2(x - H * 0.1 + ls, base_y - H * 0.42, H * 0.08, H * 0.42), dark)
		draw_rect(Rect2(x + 0.02 * H - ls, base_y - H * 0.42, H * 0.08, H * 0.42), dark)
	var by := base_y - absf(step) * H * 0.02
	# Body
	draw_rect(Rect2(x - H * 0.16, by - H * 0.8, H * 0.32, H * 0.4), tunic)
	if kit.get("armor", "") in ["chain", "plate"]:
		draw_rect(Rect2(x - H * 0.16, by - H * 0.8, H * 0.32, H * 0.08), steel)
	if team == 0 and H > 10:
		draw_rect(Rect2(x - H * 0.025, by - H * 0.76, H * 0.05, H * 0.3), red)
		draw_rect(Rect2(x - H * 0.1, by - H * 0.66, H * 0.2, H * 0.05), red)
	# Head and helmet
	var hy := by - H * 0.9
	draw_circle(Vector2(x, hy), H * 0.09, skin)
	match kit.get("armor", ""):
		"plate":
			draw_circle(Vector2(x, hy), H * 0.1, steel)
			draw_rect(Rect2(x - H * 0.07, hy - H * 0.01, H * 0.14, H * 0.02), dark)
		"chain":
			draw_rect(Rect2(x - H * 0.1, hy - H * 0.1, H * 0.2, H * 0.08), steel)
	# Weapon
	var wcol := _fog(Color(0.55, 0.42, 0.26), d)
	var hand := Vector2(x + H * 0.2, by - H * 0.58)
	match kit.get("weapon", ""):
		"spear", "pole_arm":
			var tip := hand + Vector2(H * 0.05 + jab * H * 0.25, -H * 0.85 + jab * H * 0.5)
			draw_line(hand + Vector2(0, H * 0.3), tip, wcol, maxf(1.0, H * 0.035))
			draw_line(tip, tip + (tip - hand).normalized() * H * 0.1, steel, maxf(1.0, H * 0.05))
		"lance":
			draw_line(hand, hand + Vector2(H * 0.9, -H * 0.15 + jab * H * 0.1), wcol, maxf(1.0, H * 0.05))
		"two_handed_sword":
			draw_line(hand, hand + Vector2(H * 0.1 - jab * H * 0.4, -H * 0.7 + jab * H * 0.5), _fog(Color(0.6, 0.9, 1.0), d), maxf(1.0, H * 0.06))
		"dagger":
			draw_line(hand, hand + Vector2(H * 0.08, -H * 0.12), steel, maxf(1.0, H * 0.03))
		_:
			draw_line(hand, hand + Vector2(H * 0.15 + jab * H * 0.2, -H * 0.38 + jab * H * 0.3), steel, maxf(1.0, H * 0.045))
	if kit.get("missile", "") != "":
		var mc := Vector2(x, by - H * 0.62)
		draw_line(mc + Vector2(-H * 0.22, 0), mc + Vector2(H * 0.22, 0), wcol, maxf(1.0, H * 0.04))
		if kit["missile"] == "crossbow":
			draw_line(mc + Vector2(-H * 0.18, -H * 0.06), mc + Vector2(H * 0.18, -H * 0.06), dark, maxf(1.0, H * 0.03))
	# Shield
	if kit.get("shield", "") != "":
		var sh := Rect2(x - H * 0.3, by - H * 0.78, H * 0.22, H * 0.34)
		draw_rect(sh, _fog(Color(0.92, 0.9, 0.84), d) if team == 0 else _fog(Color(0.36, 0.26, 0.16), d))
		if team == 0 and H > 12:
			draw_rect(Rect2(sh.position.x + sh.size.x * 0.42, sh.position.y + sh.size.y * 0.1, sh.size.x * 0.16, sh.size.y * 0.8), red)
			draw_rect(Rect2(sh.position.x + sh.size.x * 0.12, sh.position.y + sh.size.y * 0.32, sh.size.x * 0.76, sh.size.y * 0.13), red)
	if u["type"] == "zealot" and H > 8:
		draw_circle(Vector2(x, by - H * 0.6), H * 0.06, Color(0.5, 0.95, 1.0, 0.8))


func _draw_hands(hero: Dictionary) -> void:
	var c: Dictionary = hero["c"]
	var bob: float = sin(battle.time * 8.0) * 6.0 * hero["move"].length()
	# Shield on the left arm.
	if c.get("shield", "") != "":
		var sx := _w * 0.08
		var sy: float = _h * 0.62 + bob
		var sw := _h * 0.26
		var pts := PackedVector2Array([Vector2(sx, sy), Vector2(sx + sw, sy), Vector2(sx + sw, sy + sw * 0.9), Vector2(sx + sw * 0.5, sy + sw * 1.4), Vector2(sx, sy + sw * 0.9)])
		draw_colored_polygon(pts, Color(0.9, 0.87, 0.8))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.45, 0.35, 0.2), 5.0)
		draw_rect(Rect2(sx + sw * 0.43, sy + sw * 0.08, sw * 0.14, sw * 1.0), UI.RED)
		draw_rect(Rect2(sx + sw * 0.12, sy + sw * 0.32, sw * 0.76, sw * 0.13), UI.RED)
	# Weapon in the right hand, swinging.
	var swing := float(hero["swing"]) / 0.35
	var pivot := Vector2(_w * 0.8, _h + 20.0 + bob)
	var rot := -0.35 - sin(swing * PI) * 1.2
	draw_set_transform(pivot, rot, Vector2.ONE)
	var L := _h * 0.55
	var wood := Color(0.42, 0.3, 0.18)
	var steel := Color(0.72, 0.74, 0.78)
	var wpn: String = c.get("weapon", "")
	match wpn:
		"war_hammer", "mace":
			draw_rect(Rect2(-8, -L, 16, L), wood)
			if wpn == "war_hammer":
				draw_rect(Rect2(-40, -L - 28, 80, 36), steel)
				draw_rect(Rect2(-40, -L - 28, 80, 36), Color(0.3, 0.3, 0.32), false, 3.0)
			else:
				draw_circle(Vector2(0, -L - 10), 28, steel)
		"spear", "pole_arm", "lance":
			draw_rect(Rect2(-7, -L * 1.4, 14, L * 1.4), wood)
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -L * 1.4), Vector2(14, -L * 1.4), Vector2(0, -L * 1.4 - 60)]), steel)
		_:
			draw_rect(Rect2(-10, -L * 0.25, 20, L * 0.25), wood)
			draw_rect(Rect2(-40, -L * 0.3, 80, 12), Color(0.6, 0.5, 0.25))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -L * 0.3), Vector2(12, -L * 0.3), Vector2(8, -L * 1.1), Vector2(0, -L * 1.2), Vector2(-8, -L * 1.1)]), steel)
	draw_set_transform(Vector2.ZERO)


func _draw_hud(hero: Dictionary) -> void:
	var c: Dictionary = hero["c"]
	# Hurt flash and low-health edge.
	var hp_frac := clampf(float(c["hp"]) / maxf(1.0, float(c["max_hp"])), 0.0, 1.0)
	var red_a := float(hero["hurt"]) * 0.8 + (0.35 if hp_frac < 0.3 else 0.0)
	if red_a > 0.0:
		for i in 6:
			var t := float(i) * 14.0
			draw_rect(Rect2(t, t, _w - t * 2, _h - t * 2), Color(0.7, 0.05, 0.05, red_a * (1.0 - i / 6.0) * 0.5), false, 14.0)
	# Crosshair: red when a foe is within reach.
	var cc := Vector2(_w * 0.5, _h * 0.5)
	var in_reach: bool = battle._hero_target(battle.HERO_REACH, 0.7) >= 0
	var ccol := UI.BAD if in_reach else Color(1, 1, 1, 0.7)
	draw_line(cc + Vector2(-14, 0), cc + Vector2(-5, 0), ccol, 3.0)
	draw_line(cc + Vector2(5, 0), cc + Vector2(14, 0), ccol, 3.0)
	draw_line(cc + Vector2(0, -14), cc + Vector2(0, -5), ccol, 3.0)
	draw_line(cc + Vector2(0, 5), cc + Vector2(0, 14), ccol, 3.0)
	# Hero sheet strip.
	var bx := 230.0
	draw_rect(Rect2(bx, 14, _w - bx - 230, 64), Color(0.08, 0.06, 0.04, 0.75))
	var wname: String = BX.ITEMS[c["weapon"]]["name"] if c["weapon"] != "" else "Fists"
	draw_string(font, Vector2(bx + 12, 40), "%s   %s %d   AC %d   %s d%d" % [c["name"], c["cls"], int(c["level"]), BX.ac(c), wname, BX.weapon_die(c)], HORIZONTAL_ALIGNMENT_LEFT, _w - bx - 250, 20, UI.PARCHMENT)
	draw_rect(Rect2(bx + 12, 50, _w - bx - 254, 16), Color(0.2, 0.05, 0.05))
	draw_rect(Rect2(bx + 12, 50, (_w - bx - 254) * hp_frac, 16), UI.GOOD.lerp(UI.BAD, 1.0 - hp_frac))
	draw_string(font, Vector2(bx + 16, 64), "HP %d/%d   felled %d" % [int(c["hp"]), int(c["max_hp"]), int(hero["kills"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	_draw_minimap(hero)
	# Buttons
	_button(_tactical_rect(), "TACTICAL")
	_button(_rally_rect(), "TO ME!")
	var sc := _swing_center()
	draw_circle(sc, 82, Color(0.55, 0.12, 0.12, 0.55 if float(hero["cd"]) <= 0 else 0.25))
	draw_arc(sc, 82, 0, TAU, 40, UI.GOLD, 3.0)
	draw_string(font, sc + Vector2(-80, 10), "STRIKE", HORIZONTAL_ALIGNMENT_CENTER, 160, 26, UI.PARCHMENT)
	if c.get("missile", "") != "":
		var sh := _shoot_center()
		draw_circle(sh, 54, Color(0.2, 0.25, 0.3, 0.6 if float(hero["mcd"]) <= 0 else 0.25))
		draw_arc(sh, 54, 0, TAU, 32, UI.GOLD, 3.0)
		draw_string(font, sh + Vector2(-50, 8), "SHOOT", HORIZONTAL_ALIGNMENT_CENTER, 100, 20, UI.PARCHMENT)
	if move_touch >= 0:
		draw_arc(move_origin, JOY_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(move_origin + hero["move"] * JOY_RADIUS, 30, Color(1, 1, 1, 0.3))
	else:
		draw_string(font, Vector2(20, _h - 24), "left thumb: walk   right thumb: look", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))


func _button(r: Rect2, text: String) -> void:
	draw_rect(r, Color(0.26, 0.2, 0.13, 0.85))
	draw_rect(r, UI.GOLD, false, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 9), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, UI.PARCHMENT)


func _draw_minimap(hero: Dictionary) -> void:
	var F: Vector2 = battle.FIELD
	var mw := 200.0
	var sc := mw / F.x
	var o := Vector2(14, 14)
	draw_rect(Rect2(o, F * sc), Color(0.15, 0.2, 0.1, 0.8))
	draw_rect(Rect2(o, F * sc), UI.GOLD.darkened(0.3), false, 2.0)
	for u in battle.units:
		if u["state"] != "ok" and u["state"] != "rout":
			continue
		var r := maxf(3.0, battle.radius(u) * sc)
		var col := Color(0.85, 0.2, 0.2) if u["team"] == 0 else Color(0.15, 0.12, 0.1)
		if u["state"] == "rout":
			col.a = 0.5
		draw_rect(Rect2(o + u["pos"] * sc - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), col)
	var hp: Vector2 = o + hero["pos"] * sc
	var f := Vector2.from_angle(float(hero["angle"]))
	draw_colored_polygon(PackedVector2Array([hp + f * 9, hp + f.rotated(2.5) * 6, hp + f.rotated(-2.5) * 6]), UI.GOLD)
