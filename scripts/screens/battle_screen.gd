extends Control
## Sword & Banner-style field battle: deploy, give orders by tapping, morale and rout.

var args := {}
var army_key := ""
var phase := "deploy"
var units: Array = []
var selected := -1
var speed := 1.0
var projectiles: Array = []
var decor: Array = []
var result_shown := false

var info: Label
var buttons: HBoxContainer
var start_btn: Button
var speed_btn: Button

const TOP_H := 150.0
const BOTTOM_H := 130.0


func _ready() -> void:
	army_key = args.get("army", "brigands_small")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.day * 31 + Game.current_node
	for i in 40:
		decor.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(10, 40), "k": rng.randi() % 3})
	_build_ui()
	_spawn()


func _build_ui() -> void:
	var top := UI.panel()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, TOP_H - 10)
	add_child(top)
	info = UI.label("", 21)
	top.add_child(info)

	var bottom := UI.panel()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_H
	add_child(bottom)
	buttons = UI.hbox(8)
	bottom.add_child(buttons)
	start_btn = UI.button("Begin battle", _begin, 84)
	buttons.add_child(start_btn)


func _field() -> Rect2:
	return Rect2(0, TOP_H, size.x, size.y - TOP_H - BOTTOM_H)


func _deploy_zone() -> Rect2:
	var f := _field()
	return Rect2(f.position.x, f.end.y - f.size.y * 0.33, f.size.x, f.size.y * 0.33)


# ---------------------------------------------------------------- setup

func _spawn() -> void:
	# Wait one frame for size to be known.
	await get_tree().process_frame
	var f := _field()
	var mine := []
	for i in Game.squads.size():
		var s: Dictionary = Game.squads[i]
		if int(s["men"]) > 0:
			mine.append(i)
	for k in mine.size():
		var i: int = mine[k]
		var s: Dictionary = Game.squads[i]
		var x := f.position.x + f.size.x * (k + 1) / (mine.size() + 1.0)
		var y := f.end.y - 70.0 - (40.0 if Game.unit(s["type"])["range"] > 0 else 0.0)
		units.append(_make(0, s["type"], s["name"], int(s["men"]), Vector2(x, y), i, Game.squad_level(s)))
	var army: Dictionary = GameData.ARMIES[army_key]
	var list: Array = army["squads"]
	var scale_mult := 1.0 + Game.renown / 150.0
	for k in list.size():
		var e: Array = list[k]
		var x := f.position.x + f.size.x * (k + 1) / (list.size() + 1.0)
		var u: Dictionary = GameData.UNITS[e[0]]
		var y := f.position.y + 70.0 + (0.0 if u["range"] > 0 else 50.0)
		units.append(_make(1, e[0], u["name"], int(e[1] * scale_mult), Vector2(x, y), -1, 0))
	_update_info()
	if mine.is_empty():
		_finish(false)


func _make(team: int, type: String, nm: String, men: int, pos: Vector2, src: int, level: int) -> Dictionary:
	return {"team": team, "type": type, "u": GameData.UNITS[type], "name": nm, "men": float(men),
		"start": men, "pos": pos, "move_to": pos, "has_move": false, "target": -1, "morale": 100.0,
		"state": "ok", "cd": 0.5, "charge": 0.0, "moving": false, "level": level, "src": src,
		"kills": 0.0, "flash": 0.0, "aggressive": false}


func _begin() -> void:
	phase = "fight"
	start_btn.queue_free()
	buttons.add_child(UI.button("All attack", _all_attack, 84))
	buttons.add_child(UI.button("Hold", _hold, 84))
	speed_btn = UI.button("Speed 1x", _toggle_speed, 84)
	buttons.add_child(speed_btn)
	buttons.add_child(UI.button("Retreat", _retreat, 84))
	_update_info()


# ---------------------------------------------------------------- orders

func _all_attack() -> void:
	for i in units.size():
		var s: Dictionary = units[i]
		if s["team"] == 0 and s["state"] == "ok":
			s["target"] = _nearest_enemy(i, 99999.0)
			s["has_move"] = false
			s["aggressive"] = true


func _hold() -> void:
	for i in units.size():
		var s: Dictionary = units[i]
		if s["team"] == 0 and s["state"] == "ok" and (selected < 0 or selected == i):
			s["target"] = -1
			s["has_move"] = false
			s["aggressive"] = false


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	speed_btn.text = "Speed %dx" % int(speed)


func _retreat() -> void:
	for s in units:
		if s["team"] == 0 and s["state"] == "ok":
			if _in_melee(units.find(s)) >= 0:
				s["men"] = float(s["men"]) * 0.85
	_finish(false)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if phase == "over":
		return
	var pos: Vector2 = event.position
	if not _field().has_point(pos):
		return
	accept_event()
	var hit := _unit_at(pos)
	if hit >= 0 and units[hit]["team"] == 0 and units[hit]["state"] == "ok":
		selected = -1 if selected == hit else hit
	elif phase == "deploy":
		if selected >= 0 and _deploy_zone().has_point(pos):
			units[selected]["pos"] = pos
			units[selected]["move_to"] = pos
	elif selected >= 0 and units[selected]["state"] == "ok":
		var s: Dictionary = units[selected]
		if hit >= 0 and units[hit]["team"] == 1:
			s["target"] = hit
			s["has_move"] = false
			s["aggressive"] = true
		else:
			s["target"] = -1
			s["move_to"] = pos
			s["has_move"] = true
			s["aggressive"] = false
	_update_info()
	queue_redraw()


func _unit_at(pos: Vector2) -> int:
	var best := -1
	var best_d := 9999.0
	for i in units.size():
		var s: Dictionary = units[i]
		if s["state"] != "ok":
			continue
		var d: float = s["pos"].distance_to(pos)
		if d < _radius(s) + 14.0 and d < best_d:
			best_d = d
			best = i
	return best


# ---------------------------------------------------------------- simulation

func _radius(s: Dictionary) -> float:
	return 18.0 + sqrt(maxf(float(s["men"]), 1.0)) * 4.6


func _contact(a: Dictionary, b: Dictionary) -> float:
	return _radius(a) + _radius(b) - 4.0


func _valid_target(i: int, t: int) -> bool:
	return t >= 0 and t < units.size() and units[t]["state"] == "ok" and units[t]["team"] != units[i]["team"]


func _nearest_enemy(i: int, max_d: float) -> int:
	var s: Dictionary = units[i]
	var best := -1
	var best_d := max_d
	for j in units.size():
		if _valid_target(i, j):
			var d: float = s["pos"].distance_to(units[j]["pos"])
			if d < best_d:
				best_d = d
				best = j
	return best


func _in_melee(i: int) -> int:
	var s: Dictionary = units[i]
	var tgt: int = s["target"]
	if _valid_target(i, tgt) and s["pos"].distance_to(units[tgt]["pos"]) <= _contact(s, units[tgt]) + 6.0:
		return tgt
	for j in units.size():
		if _valid_target(i, j) and s["pos"].distance_to(units[j]["pos"]) <= _contact(s, units[j]) + 6.0:
			return j
	return -1


func _process(delta: float) -> void:
	if phase == "fight":
		var dt := minf(delta, 0.05) * speed
		_step(dt)
	queue_redraw()


func _step(dt: float) -> void:
	var f := _field()
	for i in units.size():
		var s: Dictionary = units[i]
		s["flash"] = maxf(0.0, float(s["flash"]) - dt)
		s["charge"] = maxf(0.0, float(s["charge"]) - dt)
		s["cd"] = float(s["cd"]) - dt
		if s["state"] == "rout":
			var away := 1.0 if s["team"] == 0 else -1.0
			s["pos"] += Vector2(0, away) * float(s["u"]["speed"]) * 1.1 * dt
			if s["pos"].y > f.end.y + 30 or s["pos"].y < f.position.y - 30:
				s["state"] = "gone"
			continue
		if s["state"] != "ok":
			continue
		_think(i)
		var melee := _in_melee(i)
		var u: Dictionary = s["u"]
		var ranged: bool = u["range"] > 0
		if melee >= 0:
			if s["moving"] and u["cav"]:
				s["charge"] = 1.6
			s["moving"] = false
			_melee(i, melee, dt)
		else:
			var tgt: int = s["target"]
			var dest := Vector2(-1, -1)
			if _valid_target(i, tgt):
				var t: Dictionary = units[tgt]
				var d: float = s["pos"].distance_to(t["pos"])
				if ranged and d <= float(u["range"]):
					dest = Vector2(-1, -1)
					if s["cd"] <= 0.0:
						_volley(i, tgt)
				else:
					dest = t["pos"]
			elif s["has_move"]:
				dest = s["move_to"]
				if s["pos"].distance_to(dest) < 5.0:
					s["has_move"] = false
					dest = Vector2(-1, -1)
			if ranged and dest.x < 0 and s["cd"] <= 0.0:
				var nt := _nearest_enemy(i, float(u["range"]))
				if nt >= 0:
					_volley(i, nt)
			if dest.x >= 0:
				var dir: Vector2 = (dest - s["pos"]).normalized()
				s["pos"] += dir * float(u["speed"]) * dt
				s["moving"] = true
			else:
				s["moving"] = false
			s["morale"] = minf(100.0, float(s["morale"]) + 3.0 * dt)
	_separate()
	_tick_projectiles(dt)
	_check_end()
	if selected >= 0 and units[selected]["state"] != "ok":
		selected = -1
	_update_info()


func _think(i: int) -> void:
	var s: Dictionary = units[i]
	var u: Dictionary = s["u"]
	if s["team"] == 1:
		if not _valid_target(i, s["target"]):
			s["target"] = _nearest_enemy(i, 99999.0)
	else:
		if not _valid_target(i, s["target"]):
			s["target"] = -1
			if s["aggressive"]:
				# Squads sent to attack pick a new foe when theirs falls.
				s["target"] = _nearest_enemy(i, 99999.0)
			elif not s["has_move"] and u["range"] == 0:
				# Idle squads defend themselves.
				s["target"] = _nearest_enemy(i, 130.0)


func _mult(att: Dictionary, def: Dictionary) -> float:
	var m := 1.0 + 0.1 * int(att["level"])
	var au: Dictionary = att["u"]
	var du: Dictionary = def["u"]
	if du["cav"] and float(au["anti_cav"]) > 1.0:
		m *= float(au["anti_cav"])
	if au["cav"] and float(att["charge"]) > 0.0 and float(du["anti_cav"]) <= 1.0:
		m *= 2.2
	return m


func _melee(i: int, j: int, dt: float) -> void:
	var a: Dictionary = units[i]
	var b: Dictionary = units[j]
	var au: Dictionary = a["u"]
	var du: Dictionary = b["u"]
	var front := minf(float(a["men"]), 20.0)
	var defv := float(du["def"]) * (1.0 + 0.1 * int(b["level"]))
	var cas := front * float(au["atk"]) * _mult(a, b) / (defv * float(du["hp"])) * 0.26 * dt
	_hurt(b, cas, a)


func _volley(i: int, j: int) -> void:
	var a: Dictionary = units[i]
	var b: Dictionary = units[j]
	var au: Dictionary = a["u"]
	var du: Dictionary = b["u"]
	a["cd"] = float(au["reload"])
	var defv := float(du["def"]) * (1.0 + 0.1 * int(b["level"]))
	var cas := float(a["men"]) * float(au["ratk"]) * (1.0 + 0.1 * int(a["level"])) / (defv * float(du["hp"])) * 0.45
	_hurt(b, cas, a)
	for k in 4:
		var jitter := Vector2(randf_range(-14, 14), randf_range(-10, 10))
		projectiles.append({"a": a["pos"] + jitter, "b": b["pos"] + jitter * 1.4, "t": -k * 0.06})


func _hurt(t: Dictionary, cas: float, by: Dictionary) -> void:
	cas = minf(cas, float(t["men"]))
	t["men"] = float(t["men"]) - cas
	by["kills"] = float(by["kills"]) + cas
	t["flash"] = 0.15
	var nerve := float(t["u"]["nerve"])
	t["morale"] = float(t["morale"]) - cas * (100.0 / maxf(float(t["start"]), 1.0)) * 1.4 * nerve
	if float(t["men"]) < 0.5:
		t["state"] = "dead"
		t["men"] = 0.0
		_shock(t)
	elif float(t["morale"]) <= 0.0:
		t["state"] = "rout"
		_shock(t)


## A squad breaking shakes its neighbours.
func _shock(broken: Dictionary) -> void:
	for s in units:
		if s["team"] == broken["team"] and s["state"] == "ok" and s["pos"].distance_to(broken["pos"]) < 170.0:
			s["morale"] = float(s["morale"]) - 15.0 * float(s["u"]["nerve"])
			if float(s["morale"]) <= 0.0:
				s["state"] = "rout"


func _separate() -> void:
	for i in units.size():
		var a: Dictionary = units[i]
		if a["state"] != "ok":
			continue
		for j in range(i + 1, units.size()):
			var b: Dictionary = units[j]
			if b["state"] != "ok":
				continue
			var min_d := _contact(a, b) if a["team"] != b["team"] else _radius(a) + _radius(b) + 4.0
			var delta: Vector2 = b["pos"] - a["pos"]
			var d := delta.length()
			if d < min_d and d > 0.01:
				var push := delta / d * (min_d - d) * 0.5
				a["pos"] -= push
				b["pos"] += push
	var f := _field().grow(-20)
	for s in units:
		if s["state"] == "ok":
			s["pos"] = s["pos"].clamp(f.position, f.end)


func _tick_projectiles(dt: float) -> void:
	var keep := []
	for p in projectiles:
		p["t"] = float(p["t"]) + dt * 2.5
		if p["t"] < 1.0:
			keep.append(p)
	projectiles = keep


func _check_end() -> void:
	var alive := [0, 0]
	for s in units:
		if s["state"] == "ok":
			alive[int(s["team"])] += 1
	if alive[1] == 0:
		_finish(true)
	elif alive[0] == 0:
		_finish(false)


func _finish(victory: bool) -> void:
	if result_shown:
		return
	result_shown = true
	phase = "over"
	var losses := []
	var kills := []
	for i in Game.squads.size():
		losses.append(0)
		kills.append(0)
	var enemy_dead := 0.0
	for s in units:
		if s["team"] == 0:
			var src: int = s["src"]
			losses[src] = int(s["start"]) - int(round(float(s["men"])))
			kills[src] = int(float(s["kills"]))
		else:
			enemy_dead += float(s["start"]) - float(s["men"])
	var summary := Game.apply_battle_result({"victory": victory, "losses": losses, "kills": kills})
	summary = "Enemy fallen: %d\n%s" % [int(enemy_dead), summary]
	for c in buttons.get_children():
		c.queue_free()
	var overlay := UI.panel()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	overlay.offset_left = 24
	overlay.offset_right = -24
	overlay.offset_top = size.y * 0.22
	add_child(overlay)
	var v := UI.vbox(14)
	overlay.add_child(v)
	v.add_child(UI.label("VICTORY" if victory else "DEFEAT", 48, UI.GOLD if victory else UI.BAD, true))
	v.add_child(UI.label(summary, 24))
	v.add_child(UI.button("Continue", func(): Game.after_battle(victory), 90))


# ---------------------------------------------------------------- display

func _update_info() -> void:
	if info == null:
		return
	var army: Dictionary = GameData.ARMIES[army_key]
	var head := "%s vs the Company of the Cross" % army["name"]
	var body := ""
	if phase == "deploy":
		body = "Deploy: tap a squad, then tap inside the gold zone. Spearmen stop horse; crossbows shoot far; knights charge."
	elif phase == "fight":
		if selected >= 0:
			var s: Dictionary = units[selected]
			body = "%s (%s) - %d/%d men - nerve %d%%\nTap ground to move, tap an enemy to attack." % [s["name"], s["u"]["name"], int(ceil(float(s["men"]))), int(s["start"]), int(maxf(0, float(s["morale"])))]
		else:
			body = "Tap one of your squads to give it orders."
	info.text = head + "\n" + body


func _draw() -> void:
	var f := _field()
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	draw_rect(f, Color(0.27, 0.33, 0.18))
	for d in decor:
		var p := f.position + Vector2(d["p"].x * f.size.x, d["p"].y * f.size.y)
		var col := Color(0.24, 0.3, 0.16) if d["k"] == 0 else (Color(0.31, 0.36, 0.2) if d["k"] == 1 else Color(0.3, 0.28, 0.2))
		draw_circle(p, d["r"], col)
	if phase == "deploy":
		var z := _deploy_zone()
		draw_rect(z, Color(0.79, 0.64, 0.29, 0.12))
		draw_rect(z, Color(0.79, 0.64, 0.29, 0.6), false, 2.0)
	# Orders of the selected squad
	if selected >= 0 and phase == "fight":
		var s: Dictionary = units[selected]
		if _valid_target(selected, s["target"]):
			draw_line(s["pos"], units[s["target"]]["pos"], UI.BAD, 3.0)
		elif s["has_move"]:
			draw_line(s["pos"], s["move_to"], UI.GOLD, 2.0)
			draw_circle(s["move_to"], 6, UI.GOLD)
	var font := ThemeDB.fallback_font
	for i in units.size():
		var s: Dictionary = units[i]
		if s["state"] == "dead" or s["state"] == "gone":
			continue
		_draw_squad(s, i == selected, font)
	for p in projectiles:
		var t := clampf(float(p["t"]), 0.0, 1.0)
		if p["t"] < 0:
			continue
		var pos: Vector2 = p["a"].lerp(p["b"], t)
		var dir: Vector2 = (p["b"] - p["a"]).normalized()
		draw_line(pos - dir * 10, pos, Color(0.95, 0.9, 0.7), 2.0)


func _draw_squad(s: Dictionary, is_sel: bool, font: Font) -> void:
	var r := _radius(s)
	var pos: Vector2 = s["pos"]
	var u: Dictionary = s["u"]
	var w := r * 2.0
	var h := r * (1.0 if u["cav"] else 0.85)
	var rect := Rect2(pos - Vector2(w, h) / 2.0, Vector2(w, h))
	var base := Color(0.55, 0.12, 0.12) if s["team"] == 0 else Color(0.18, 0.15, 0.13)
	if s["state"] == "rout" and int(Time.get_ticks_msec() / 150) % 2 == 0:
		base = base.lightened(0.3)
	if float(s["flash"]) > 0:
		base = base.lightened(0.35)
	draw_rect(rect, base)
	# Men as dots
	var n := int(ceil(float(s["men"])))
	var cols := maxi(1, int(ceil(sqrt(n * w / h))))
	var rows := int(ceil(n / float(cols)))
	var dot: Color = u["color"]
	for k in n:
		var cx := k % cols
		var cy := int(k / cols)
		var dp := rect.position + Vector2((cx + 0.5) * w / cols, (cy + 0.5) * h / maxf(rows, 1))
		draw_circle(dp, 3.4 if not u["cav"] else 4.4, dot)
	var border := UI.GOLD if is_sel else (Color(0.95, 0.88, 0.7) if s["team"] == 0 else Color(0.05, 0.05, 0.05))
	draw_rect(rect, border, false, 4.0 if is_sel else 2.0)
	# Banner
	var top := Vector2(pos.x, rect.position.y)
	draw_line(top, top + Vector2(0, -22), Color(0.25, 0.18, 0.1), 2.0)
	var flag_col := Color(0.93, 0.89, 0.78) if s["team"] == 0 else Color(0.35, 0.3, 0.25)
	draw_rect(Rect2(top + Vector2(1, -22), Vector2(16, 11)), flag_col)
	if s["team"] == 0:
		draw_rect(Rect2(top + Vector2(7.5, -22), Vector2(3, 11)), UI.RED)
		draw_rect(Rect2(top + Vector2(3, -18), Vector2(12, 3)), UI.RED)
	var tag := "%s %d" % [u["short"], int(ceil(float(s["men"])))]
	if int(s["level"]) > 0:
		tag += " " + "★".repeat(int(s["level"]))
	draw_string_outline(font, rect.position + Vector2(-20, h + 22), tag, HORIZONTAL_ALIGNMENT_CENTER, w + 40, 18, 4, Color.BLACK)
	draw_string(font, rect.position + Vector2(-20, h + 22), tag, HORIZONTAL_ALIGNMENT_CENTER, w + 40, 18, UI.PARCHMENT)
	# Nerve bar
	var m := clampf(float(s["morale"]) / 100.0, 0.0, 1.0)
	draw_rect(Rect2(rect.position + Vector2(0, -6), Vector2(w, 4)), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(rect.position + Vector2(0, -6), Vector2(w * m, 4)), UI.GOOD.lerp(UI.BAD, 1.0 - m))
