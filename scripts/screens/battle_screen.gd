extends Control
## Field battle. One simulation in fixed world coordinates, two ways to see it:
## the tactical view (Sword & Banner / Total War) and the first-person view (FpsView),
## switchable at any moment. Combat numbers come from the men's B/X sheets.

const FpsView := preload("res://scripts/screens/fps_view.gd")

const FIELD := Vector2(1200, 760)       ## world size in px (8 px = 1 metre)
const K_MELEE := 0.075
const K_MISSILE := 0.13
const HERO_REACH := 20.0                ## world px (~2.5 m)
const HERO_WALK := 42.0
const HERO_RUN := 68.0

var args := {}
var army_key := ""
var phase := "deploy"
var units: Array = []
var selected := -1
var speed := 1.0
var projectiles: Array = []
var decor: Array = []
var corpses: Array = []
var floaters: Array = []
var result_shown := false
var time := 0.0

## The hero you can walk around as in first person.
var hero := {}
var fps_mode := false

var info: Label
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var buttons: HBoxContainer
var start_btn: Button
var speed_btn: Button
var fps_btn: Button
var fps: Control
var landscape := false


func _ready() -> void:
	army_key = args.get("army", "brigands_small")
	mouse_filter = Control.MOUSE_FILTER_STOP
	if OS.has_feature("mobile"):
		landscape = true
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		get_tree().root.content_scale_size = Vector2i(1280, 720)
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.day * 31 + Game.current_node
	for i in 70:
		decor.append({"p": Vector2(rng.randf() * FIELD.x, rng.randf() * FIELD.y), "r": rng.randf_range(10, 45), "k": rng.randi() % 3})
	_build_ui()
	_spawn()


func _exit_tree() -> void:
	if landscape:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
		get_tree().root.content_scale_size = Vector2i(720, 1280)


func _build_ui() -> void:
	top_panel = UI.panel()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top_panel)
	info = UI.label("", 20)
	top_panel.add_child(info)

	bottom_panel = UI.panel()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom_panel)
	buttons = UI.hbox(8)
	bottom_panel.add_child(buttons)
	start_btn = UI.button("Begin battle", _begin, 76)
	buttons.add_child(start_btn)

	fps = FpsView.new()
	fps.battle = self
	fps.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fps.visible = false
	add_child(fps)


# ---------------------------------------------------------------- world <-> screen

func _view_rect() -> Rect2:
	var top := top_panel.size.y if top_panel else 120.0
	var bottom := bottom_panel.size.y if bottom_panel else 110.0
	return Rect2(0, top, size.x, maxf(100.0, size.y - top - bottom))


func _view_scale() -> float:
	var r := _view_rect()
	return minf(r.size.x / FIELD.x, r.size.y / FIELD.y)


func _view_origin() -> Vector2:
	var r := _view_rect()
	var sc := _view_scale()
	return r.position + (r.size - FIELD * sc) / 2.0


func to_screen(p: Vector2) -> Vector2:
	return _view_origin() + p * _view_scale()


func to_world(p: Vector2) -> Vector2:
	return (p - _view_origin()) / _view_scale()


func _deploy_zone() -> Rect2:
	return Rect2(0, FIELD.y * 0.66, FIELD.x, FIELD.y * 0.34)


# ---------------------------------------------------------------- setup

func _spawn() -> void:
	await get_tree().process_frame
	var mine := []
	for i in Game.squads.size():
		var s: Dictionary = Game.squads[i]
		if int(s["men"]) > 0:
			mine.append(i)
	for k in mine.size():
		var i: int = mine[k]
		var s: Dictionary = Game.squads[i]
		var u: Dictionary = Game.unit(s["type"])
		var x := FIELD.x * (k + 1) / (mine.size() + 1.0)
		var y := FIELD.y - 70.0 - (45.0 if u["range"] > 0 else 0.0)
		var nu := _make(0, s["type"], s["name"], int(s["men"]), Vector2(x, y), i, Game.squad_level(s))
		nu["st"] = BX.group_stats(s["members"])
		for c in s["members"]:
			if c["status"] == "ok" and c["cls"] == "Cleric":
				nu["blessed"] = true
		units.append(nu)
	var army: Dictionary = GameData.ARMIES[army_key]
	var list: Array = army["squads"]
	var scale_mult := 1.0 + Game.renown / 150.0
	for k in list.size():
		var e: Array = list[k]
		var u: Dictionary = GameData.UNITS[e[0]]
		var x := FIELD.x * (k + 1) / (list.size() + 1.0)
		var y := 70.0 + (0.0 if u["range"] > 0 else 50.0)
		var nu := _make(1, e[0], u["name"], int(e[1] * scale_mult), Vector2(x, y), -1, 0)
		nu["st"] = BX.kit_stats(u["cls"], int(u["level"]), u["kit"])
		units.append(nu)
	_pick_hero()
	_update_info()
	if mine.is_empty():
		_finish(false)


func _make(team: int, type: String, nm: String, men: int, pos: Vector2, src: int, level: int) -> Dictionary:
	var u: Dictionary = GameData.UNITS[type]
	var kit: Dictionary = u["kit"]
	return {"team": team, "type": type, "u": u, "name": nm, "men": float(men),
		"start": men, "pos": pos, "move_to": pos, "has_move": false, "target": -1, "morale": 100.0,
		"state": "ok", "cd": 0.5, "charge": 0.0, "moving": false, "level": level, "src": src,
		"kills": 0.0, "flash": 0.0, "aggressive": false, "blessed": false, "wounds": 0.0,
		"die": int(BX.ITEMS[kit["weapon"]]["dmg"]) if kit.has("weapon") else 4,
		"st": {}}


func _pick_hero() -> void:
	## Mateo if he can stand, else another hero, else the first sergeant.
	var best := {}
	var best_unit := -1
	for i in units.size():
		var nu: Dictionary = units[i]
		if nu["team"] != 0:
			continue
		for c in Game.squads[int(nu["src"])]["members"]:
			if c["status"] != "ok":
				continue
			var score := 0
			if c["name"].begins_with("Mateo"):
				score = 3
			elif c.get("hero", false):
				score = 2
			elif c["cls"] == "Fighter":
				score = 1
			if best.is_empty() or score > int(best.get("_score", -1)):
				best = {"c": c, "_score": score}
				best_unit = i
	if best_unit < 0:
		return
	var c: Dictionary = best["c"]
	hero = {"c": c, "unit": best_unit, "pos": units[best_unit]["pos"], "angle": -PI / 2.0,
		"cd": 0.0, "mcd": 0.0, "swing": 0.0, "hurt": 0.0, "down": false, "kills": 0,
		"attack_t": 0.0, "move": Vector2.ZERO, "run": false}


func _begin() -> void:
	phase = "fight"
	start_btn.queue_free()
	buttons.add_child(UI.button("All attack", _all_attack, 76))
	buttons.add_child(UI.button("Hold", _hold, 76))
	speed_btn = UI.button("1x", _toggle_speed, 76)
	buttons.add_child(speed_btn)
	if not hero.is_empty():
		fps_btn = UI.button("First person", toggle_fps, 76)
		buttons.add_child(fps_btn)
	buttons.add_child(UI.button("Retreat", _retreat, 76))
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
	speed_btn.text = "%dx" % int(speed)


func _retreat() -> void:
	for i in units.size():
		var s: Dictionary = units[i]
		if s["team"] == 0 and s["state"] == "ok" and _in_melee(i) >= 0:
			s["men"] = float(s["men"]) * 0.85
	_finish(false)


func toggle_fps() -> void:
	if hero.is_empty() or hero["down"] or phase == "over":
		fps_mode = false
	else:
		fps_mode = not fps_mode
	if fps_mode:
		var u: Dictionary = units[int(hero["unit"])]
		if u["state"] == "ok" and hero["pos"].distance_to(u["pos"]) < 1.0:
			# Step out to the front rank, facing the nearest foe.
			var e := _nearest_enemy(int(hero["unit"]), 99999.0)
			var face := Vector2(0, -1)
			if e >= 0:
				face = (units[e]["pos"] - u["pos"]).normalized()
			hero["angle"] = face.angle()
			hero["pos"] = u["pos"] + face * (_radius(u) + 14.0)
		speed = 1.0
		if speed_btn:
			speed_btn.text = "1x"
	fps.visible = fps_mode
	top_panel.visible = not fps_mode
	bottom_panel.visible = not fps_mode
	queue_redraw()


## Hero's squad marches to where the hero stands.
func rally_to_hero() -> void:
	if hero.is_empty():
		return
	var u: Dictionary = units[int(hero["unit"])]
	if u["state"] != "ok":
		return
	u["target"] = -1
	u["move_to"] = hero["pos"]
	u["has_move"] = true
	u["aggressive"] = false
	float_text(hero["pos"], "TO ME!", UI.GOLD)


func _gui_input(event: InputEvent) -> void:
	if fps_mode:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if phase == "over":
		return
	if not _view_rect().has_point(event.position):
		return
	var pos := to_world(event.position)
	accept_event()
	var hit := _unit_at(pos)
	if hit >= 0 and units[hit]["team"] == 0 and units[hit]["state"] == "ok":
		selected = -1 if selected == hit else hit
	elif phase == "deploy":
		if selected >= 0 and _deploy_zone().has_point(pos):
			units[selected]["pos"] = pos
			units[selected]["move_to"] = pos
			if not hero.is_empty() and int(hero["unit"]) == selected:
				hero["pos"] = pos
	elif selected >= 0 and units[selected]["state"] == "ok":
		var s: Dictionary = units[selected]
		if hit >= 0 and units[hit]["team"] == 1:
			s["target"] = hit
			s["has_move"] = false
			s["aggressive"] = true
		else:
			s["target"] = -1
			s["move_to"] = pos.clamp(Vector2(20, 20), FIELD - Vector2(20, 20))
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
		if d < _radius(s) + 22.0 and d < best_d:
			best_d = d
			best = i
	return best


# ---------------------------------------------------------------- simulation

func radius(s: Dictionary) -> float:
	return _radius(s)


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
	time += delta
	if phase == "fight":
		var dt := minf(delta, 0.05) * speed
		_step(dt)
	if fps_mode:
		fps.queue_redraw()
	else:
		queue_redraw()


func _step(dt: float) -> void:
	for i in units.size():
		var s: Dictionary = units[i]
		s["flash"] = maxf(0.0, float(s["flash"]) - dt)
		s["charge"] = maxf(0.0, float(s["charge"]) - dt)
		s["cd"] = float(s["cd"]) - dt
		if s["state"] == "rout":
			var away := 1.0 if s["team"] == 0 else -1.0
			s["pos"] += Vector2(0, away) * float(s["u"]["speed"]) * 1.1 * dt
			if s["pos"].y > FIELD.y + 40 or s["pos"].y < -40:
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
	_hero_step(dt)
	_tick_floaters(dt)
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
				s["target"] = _nearest_enemy(i, 99999.0)
			elif not s["has_move"] and u["range"] == 0:
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
	var front := minf(float(a["men"]), 20.0)
	var p := BX.hit_chance(float(a["st"]["thac0"]), float(b["st"]["ac"]))
	var cas := front * p * float(a["st"]["dmg"]) * _mult(a, b) / float(b["st"]["hp"]) * K_MELEE * dt
	_hurt(b, cas, a)


func _volley(i: int, j: int) -> void:
	var a: Dictionary = units[i]
	var b: Dictionary = units[j]
	a["cd"] = float(a["u"]["reload"])
	var p := BX.hit_chance(float(a["st"]["mthac0"]), float(b["st"]["ac"]))
	var cas := float(a["men"]) * p * float(a["st"]["mdmg"]) * (1.0 + 0.1 * int(a["level"])) / float(b["st"]["hp"]) * K_MISSILE
	_hurt(b, cas, a)
	for k in 5:
		var jitter := Vector2(randf_range(-16, 16), randf_range(-10, 10))
		projectiles.append({"a": a["pos"] + jitter, "b": b["pos"] + jitter * 1.4, "t": -k * 0.06})


func _hurt(t: Dictionary, cas: float, by: Dictionary) -> void:
	cas = minf(cas, float(t["men"]))
	var before := int(ceil(float(t["men"])))
	t["men"] = float(t["men"]) - cas
	by["kills"] = float(by["kills"]) + cas
	t["flash"] = 0.15
	var after := int(ceil(float(t["men"])))
	for k in mini(before - after, 3):
		if corpses.size() < 260:
			var r := _radius(t)
			corpses.append({"p": t["pos"] + Vector2(randf_range(-r, r), randf_range(-r * 0.4, r * 0.4)), "team": t["team"], "a": randf() * TAU})
	var nerve := float(t["u"]["nerve"]) * (0.75 if t.get("blessed", false) else 1.0)
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
			var nerve := float(s["u"]["nerve"]) * (0.75 if s.get("blessed", false) else 1.0)
			s["morale"] = float(s["morale"]) - 15.0 * nerve
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
	for s in units:
		if s["state"] == "ok":
			s["pos"] = s["pos"].clamp(Vector2(20, 20), FIELD - Vector2(20, 20))


func _tick_projectiles(dt: float) -> void:
	var keep := []
	for p in projectiles:
		p["t"] = float(p["t"]) + dt * 2.5
		if p["t"] < 1.0:
			keep.append(p)
	projectiles = keep


func float_text(p: Vector2, text: String, col: Color) -> void:
	floaters.append({"p": p, "text": text, "t": 0.0, "col": col})


func _tick_floaters(dt: float) -> void:
	var keep := []
	for f in floaters:
		f["t"] = float(f["t"]) + dt
		if f["t"] < 1.2:
			keep.append(f)
	floaters = keep


# ---------------------------------------------------------------- the hero (first person)

func _hero_step(dt: float) -> void:
	if hero.is_empty() or hero["down"]:
		return
	hero["cd"] = maxf(0.0, float(hero["cd"]) - dt)
	hero["mcd"] = maxf(0.0, float(hero["mcd"]) - dt)
	hero["swing"] = maxf(0.0, float(hero["swing"]) - dt)
	hero["hurt"] = maxf(0.0, float(hero["hurt"]) - dt)
	var u: Dictionary = units[int(hero["unit"])]
	if not fps_mode:
		# In the tactical view the hero fights inside his squad.
		if u["state"] == "ok":
			hero["pos"] = hero["pos"].lerp(u["pos"], minf(1.0, dt * 4.0))
		return
	# Walk.
	var mv: Vector2 = hero["move"]
	if mv.length() > 0.05:
		var dir := Vector2.from_angle(float(hero["angle"]))
		var right := Vector2(-dir.y, dir.x)
		var v := (dir * -mv.y + right * mv.x).limit_length(1.0)
		var spd := HERO_RUN if hero["run"] else HERO_WALK
		hero["pos"] += v * spd * dt
	# Can't walk into an enemy block: you fight its front rank.
	for e in units:
		if e["team"] == 1 and e["state"] == "ok":
			var d: Vector2 = hero["pos"] - e["pos"]
			var min_d := _radius(e) * 0.85
			if d.length() < min_d:
				hero["pos"] = e["pos"] + d.normalized() * min_d
	hero["pos"] = hero["pos"].clamp(Vector2(6, 6), FIELD - Vector2(6, 6))
	# The enemy strikes back at whoever stands in their front rank.
	hero["attack_t"] = float(hero["attack_t"]) - dt
	if hero["attack_t"] <= 0.0:
		hero["attack_t"] = 1.0
		var c: Dictionary = hero["c"]
		for e in units:
			if e["team"] != 1 or e["state"] != "ok":
				continue
			var d: float = hero["pos"].distance_to(e["pos"])
			if d > _radius(e) + 12.0:
				continue
			for k in mini(3, int(ceil(float(e["men"])))):
				var roll := BX.d(20)
				if roll >= int(round(float(e["st"]["thac0"]))) - BX.ac(c) or roll == 20:
					var dmg := BX.d(int(e["die"]))
					c["hp"] = int(c["hp"]) - dmg
					hero["hurt"] = 0.4
					float_text(hero["pos"] + Vector2(0, -4), "-%d" % dmg, UI.BAD)
		if int(c["hp"]) <= 0:
			_hero_falls()


func _hero_falls() -> void:
	var c: Dictionary = hero["c"]
	hero["down"] = true
	Game.wound(c)
	var u: Dictionary = units[int(hero["unit"])]
	if float(u["men"]) >= 1.0:
		u["men"] = float(u["men"]) - 1.0
	u["morale"] = float(u["morale"]) - 25.0
	float_text(hero["pos"], "%s FALLS!" % c["name"].to_upper(), UI.BAD)
	if fps_mode:
		toggle_fps()
	if fps_btn:
		fps_btn.disabled = true


## Melee swing from first person: a real B/X attack roll against the nearest foe in front.
func hero_swing() -> void:
	if hero.is_empty() or hero["down"] or float(hero["cd"]) > 0.0 or phase != "fight":
		return
	var c: Dictionary = hero["c"]
	hero["cd"] = 0.85
	hero["swing"] = 0.35
	var target := _hero_target(HERO_REACH, 0.7)
	if target < 0:
		return
	_hero_attack(target, BX.thac0(c) - BX.melee_bonus(c), BX.weapon_die(c), BX.melee_bonus(c))


func hero_shoot() -> void:
	if hero.is_empty() or hero["down"] or float(hero["mcd"]) > 0.0 or phase != "fight":
		return
	var c: Dictionary = hero["c"]
	if c.get("missile", "") == "":
		return
	hero["mcd"] = 2.4
	var target := _hero_target(280.0, 0.12)
	var face := Vector2.from_angle(float(hero["angle"]))
	var end_p: Vector2 = hero["pos"] + face * 260.0
	if target >= 0:
		end_p = units[target]["pos"]
	projectiles.append({"a": hero["pos"], "b": end_p, "t": 0.0})
	if target >= 0:
		_hero_attack(target, BX.thac0(c) - BX.missile_bonus(c), BX.missile_die(c), 0)


func _hero_target(reach: float, cone: float) -> int:
	var face := Vector2.from_angle(float(hero["angle"]))
	var best := -1
	var best_d := 99999.0
	for i in units.size():
		var e: Dictionary = units[i]
		if e["team"] != 1 or e["state"] != "ok":
			continue
		var rel: Vector2 = e["pos"] - hero["pos"]
		var edge := rel.length() - _radius(e) * 0.9
		if edge > reach:
			continue
		var ang := absf(face.angle_to(rel))
		# Close up the block fills your view, so the cone widens.
		var allowed := cone + atan2(_radius(e), maxf(rel.length(), 1.0))
		if ang <= allowed and edge < best_d:
			best_d = edge
			best = i
	return best


func _hero_attack(target: int, need_base: int, die: int, bonus: int) -> void:
	var e: Dictionary = units[target]
	var c: Dictionary = hero["c"]
	var roll := BX.d(20)
	var need := need_base - int(round(float(e["st"]["ac"])))
	var spot: Vector2 = hero["pos"].lerp(e["pos"], 0.5)
	if roll == 20 or (roll != 1 and roll >= need):
		var dmg := maxi(1, BX.d(die) + bonus)
		e["wounds"] = float(e["wounds"]) + dmg
		var felled := 0
		while float(e["wounds"]) >= float(e["st"]["hp"]) and e["state"] == "ok":
			e["wounds"] = float(e["wounds"]) - float(e["st"]["hp"])
			_hurt(e, 1.0, units[int(hero["unit"])])
			e["morale"] = float(e["morale"]) - 4.0
			felled += 1
		hero["kills"] = int(hero["kills"]) + felled
		float_text(spot, "%d%s" % [dmg, " - DOWN!" if felled > 0 else ""], UI.GOLD)
	else:
		float_text(spot, "miss (%d)" % roll, UI.DIM)


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
	if fps_mode:
		toggle_fps()
	var losses := []
	var kills := []
	for i in Game.squads.size():
		losses.append(0)
		kills.append(0)
	var enemy_dead := 0.0
	for i in units.size():
		var s: Dictionary = units[i]
		if s["team"] == 0:
			var src: int = s["src"]
			var lost := int(s["start"]) - int(round(float(s["men"])))
			if not hero.is_empty() and hero["down"] and int(hero["unit"]) == i:
				lost -= 1  # the hero was already carried off
			losses[src] = maxi(0, lost)
			kills[src] = int(float(s["kills"]))
		else:
			enemy_dead += float(s["start"]) - float(s["men"])
	var hero_line := ""
	if not hero.is_empty() and int(hero["kills"]) > 0:
		var c: Dictionary = hero["c"]
		hero_line = "%s felled %d with his own hand." % [c["name"], int(hero["kills"])]
		var m := BX.gain_xp(c, int(hero["kills"]) * 10)
		if m != "":
			hero_line += "\n" + m
	var summary := Game.apply_battle_result({"victory": victory, "losses": losses, "kills": kills, "enemy_dead": int(enemy_dead)})
	summary = "Enemy fallen: %d\n%s%s" % [int(enemy_dead), summary, "\n" + hero_line if hero_line != "" else ""]
	for ch in buttons.get_children():
		ch.queue_free()
	bottom_panel.visible = true
	top_panel.visible = true
	var overlay := UI.panel()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	overlay.offset_left = maxf(24.0, (size.x - 680.0) / 2.0)
	overlay.offset_right = -maxf(24.0, (size.x - 680.0) / 2.0)
	overlay.offset_top = size.y * 0.12
	add_child(overlay)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, minf(size.y * 0.7, 560.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(sc)
	var v := UI.vbox(12)
	sc.add_child(v)
	v.add_child(UI.label("VICTORY" if victory else "DEFEAT", 46, UI.GOLD if victory else UI.BAD, true))
	v.add_child(UI.label(summary, 22))
	v.add_child(UI.button("Continue", func(): Game.after_battle(victory), 84))


# ---------------------------------------------------------------- tactical display

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
			body = "%s (%s) - %d/%d men - nerve %d%% - AC %.0f THAC0 %.0f%s" % [s["name"], s["u"]["name"], int(ceil(float(s["men"]))), int(s["start"]), int(maxf(0, float(s["morale"]))), s["st"]["ac"], s["st"]["thac0"], " - blessed" if s["blessed"] else ""]
		else:
			body = "Tap a squad, then ground to move or an enemy to attack."
		if not hero.is_empty() and not hero["down"]:
			body += "   |  %s: HP %d" % [hero["c"]["name"], int(hero["c"]["hp"])]
	info.text = head + "\n" + body


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.13))
	if fps_mode:
		return
	var sc := _view_scale()
	draw_set_transform(_view_origin(), 0.0, Vector2(sc, sc))
	draw_rect(Rect2(Vector2.ZERO, FIELD), Color(0.27, 0.33, 0.18))
	for d in decor:
		var col := Color(0.24, 0.3, 0.16) if d["k"] == 0 else (Color(0.31, 0.36, 0.2) if d["k"] == 1 else Color(0.3, 0.28, 0.2))
		draw_circle(d["p"], d["r"], col)
	for c in corpses:
		draw_circle(c["p"], 3.0, Color(0.25, 0.08, 0.06, 0.8) if c["team"] == 0 else Color(0.12, 0.1, 0.08, 0.8))
	if phase == "deploy":
		var z := _deploy_zone()
		draw_rect(z, Color(0.79, 0.64, 0.29, 0.12))
		draw_rect(z, Color(0.79, 0.64, 0.29, 0.6), false, 3.0)
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
		if p["t"] < 0:
			continue
		var t := clampf(float(p["t"]), 0.0, 1.0)
		var pos: Vector2 = p["a"].lerp(p["b"], t)
		var dir: Vector2 = (p["b"] - p["a"]).normalized()
		draw_line(pos - dir * 10, pos, Color(0.95, 0.9, 0.7), 2.0)
	if not hero.is_empty() and not hero["down"]:
		var hp: Vector2 = hero["pos"]
		draw_colored_polygon(PackedVector2Array([hp + Vector2(0, -9), hp + Vector2(7, 0), hp + Vector2(0, 9), hp + Vector2(-7, 0)]), UI.GOLD)
		draw_polyline(PackedVector2Array([hp + Vector2(0, -9), hp + Vector2(7, 0), hp + Vector2(0, 9), hp + Vector2(-7, 0), hp + Vector2(0, -9)]), Color.BLACK, 1.5)
	for f in floaters:
		var fp: Vector2 = f["p"] + Vector2(0, -20 - float(f["t"]) * 24)
		draw_string_outline(font, fp + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color.BLACK)
		draw_string(font, fp + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, f["col"])
	draw_set_transform(Vector2.ZERO)


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
	for p in formation(s):
		draw_circle(p, 3.4 if not u["cav"] else 4.4, u["color"])
	var border := UI.GOLD if is_sel else (Color(0.95, 0.88, 0.7) if s["team"] == 0 else Color(0.05, 0.05, 0.05))
	draw_rect(rect, border, false, 4.0 if is_sel else 2.0)
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
	var m := clampf(float(s["morale"]) / 100.0, 0.0, 1.0)
	draw_rect(Rect2(rect.position + Vector2(0, -6), Vector2(w, 4)), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(rect.position + Vector2(0, -6), Vector2(w * m, 4)), UI.GOOD.lerp(UI.BAD, 1.0 - m))


## World positions of every man in a squad (shared by both views).
func formation(s: Dictionary) -> Array:
	var r := _radius(s)
	var u: Dictionary = s["u"]
	var w := r * 2.0
	var h := r * (1.0 if u["cav"] else 0.85)
	var origin: Vector2 = s["pos"] - Vector2(w, h) / 2.0
	var n := int(ceil(float(s["men"])))
	var cols := maxi(1, int(ceil(sqrt(n * w / h))))
	var rows := int(ceil(n / float(cols)))
	var out := []
	for k in n:
		var cx := k % cols
		var cy := int(k / cols)
		out.append(origin + Vector2((cx + 0.5) * w / cols, (cy + 0.5) * h / maxf(rows, 1)))
	return out


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and not fps_mode and event.keycode in [KEY_TAB, KEY_V] and phase == "fight":
		toggle_fps()
