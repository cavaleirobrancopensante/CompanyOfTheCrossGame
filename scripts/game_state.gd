extends Node
## Autoload "Game": the whole campaign state, the rules that change it, and screen flow.

signal screen_requested(screen_name: String, args: Dictionary)

const SAVE_PATH := "user://company_save.json"
const MAX_SQUADS := 6
const XP_LEVELS := [0, 30, 80, 160]

var gold := 0
var food := 0
var day := 1
var morale := 70
var faith := 50
var renown := 0
var reputation := {}
var squads: Array = []
var nodes: Array = []
var current_node := 0
var contract := {}
var notices: Array = []
var battle_context := {}
var town_contracts := {}  # node id (String) -> Array of offers, refreshed on visits

var rng := RandomNumberGenerator.new()


func goto(screen: String, args: Dictionary = {}) -> void:
	screen_requested.emit(screen, args)


func notice(text: String) -> void:
	notices.append(text)


func pop_notices() -> String:
	var t := "\n".join(notices)
	notices.clear()
	return t


# ---------------------------------------------------------------- new game

func new_game() -> void:
	rng.randomize()
	gold = 300
	food = 60
	day = 1
	morale = 70
	faith = 50
	renown = 0
	reputation = {"Holy See": 10, "Venice": 0, "Milan": 0, "Naples": 0}
	squads = []
	squads.append(make_squad("sword", 20, "Mateo's Own"))
	squads.append(make_squad("spear", 24))
	squads.append(make_squad("xbow", 14))
	nodes = GameData.build_map()
	current_node = 0
	for n in nodes:
		if n["name"] == GameData.START_NODE:
			current_node = n["id"]
	nodes[current_node]["visited"] = true
	contract = {}
	town_contracts = {}
	notices = []
	notice("Rome, Anno Domini 2987. Captain Mateo 'Hammerhead' and Father Martin have sixty men, three hundred gold, and a banner with a red cross. Find work.")
	save_game()


func make_squad(type: String, men: int, squad_name: String = "") -> Dictionary:
	if squad_name == "":
		var used := []
		for s in squads:
			used.append(s["name"])
		for nm in GameData.SQUAD_NAMES:
			if not used.has(nm):
				squad_name = nm
				break
		if squad_name == "":
			squad_name = "Company %d" % (squads.size() + 1)
	return {"type": type, "name": squad_name, "men": men, "wounded": 0, "xp": 0}


func unit(type: String) -> Dictionary:
	return GameData.UNITS[type]


func squad_max(s: Dictionary) -> int:
	return int(unit(s["type"])["size"])


func squad_level(s: Dictionary) -> int:
	var lvl := 0
	for i in XP_LEVELS.size():
		if int(s["xp"]) >= XP_LEVELS[i]:
			lvl = i
	return lvl


func total_men() -> int:
	var t := 0
	for s in squads:
		t += int(s["men"])
	return t


func total_wounded() -> int:
	var t := 0
	for s in squads:
		t += int(s["wounded"])
	return t


func daily_food() -> int:
	return int(ceil((total_men() + total_wounded()) / 8.0))


func daily_wage() -> int:
	var w := 0.0
	for s in squads:
		w += (int(s["men"]) + int(s["wounded"])) * float(unit(s["type"])["wage"]) / 5.0
	return int(round(w))


func is_wiped() -> bool:
	return total_men() + total_wounded() <= 0


# ---------------------------------------------------------------- time

func pass_days(n: int) -> void:
	for i in n:
		day += 1
		food -= daily_food()
		if food < 0:
			food = 0
			morale -= 8
			notice("Day %d: the bread is gone. The men go hungry." % day)
		gold -= daily_wage()
		if gold < 0:
			gold = 0
			morale -= 5
			notice("Day %d: the pay chest is empty. The men mutter." % day)
		# Wounded mend slowly on the road.
		for s in squads:
			var w := int(s["wounded"])
			if w > 0:
				var healed := maxi(1, int(w * 0.1)) if rng.randf() < 0.5 else 0
				s["wounded"] = w - healed
				s["men"] = int(s["men"]) + healed
		# Morale drifts toward a level set by faith.
		var target := 45 + faith / 4
		if morale < target:
			morale += 1
		elif morale > target:
			morale -= 1
		if morale < 20 and total_men() > 0:
			var s: Dictionary = squads[rng.randi() % squads.size()]
			var lost := maxi(1, int(int(s["men"]) * 0.1))
			lost = mini(lost, int(s["men"]))
			s["men"] = int(s["men"]) - lost
			if lost > 0:
				notice("Day %d: %d men of %s desert in the night." % [day, lost, s["name"]])
		if not contract.is_empty():
			contract["days_left"] = int(contract["days_left"]) - 1
			if int(contract["days_left"]) < 0 and not contract.get("done", false):
				var f: String = contract["faction"]
				change_rep(f, -6)
				renown = maxi(0, renown - 3)
				notice("The contract from %s has expired. %s will remember." % [nodes[int(contract["giver"])]["name"], f])
				contract = {}
	morale = clampi(morale, 0, 100)
	faith = clampi(faith, 0, 100)
	_cleanup_squads()


func _cleanup_squads() -> void:
	var keep := []
	for s in squads:
		if int(s["men"]) + int(s["wounded"]) > 0:
			keep.append(s)
		else:
			notice("%s is no more. Martin writes their names in his book." % s["name"])
	squads = keep


func change_rep(faction: String, delta: int) -> void:
	if faction == "" or not reputation.has(faction):
		return
	reputation[faction] = clampi(int(reputation[faction]) + delta, -100, 100)


# ---------------------------------------------------------------- effects

## Applies an effect dictionary. Returns {"text": String, "battle": String}.
func apply_effects(eff: Dictionary) -> Dictionary:
	var parts := []
	var battle := ""
	var extra_text := ""
	if eff.has("chance"):
		var c: Dictionary = eff["chance"]
		var won := rng.randf() < float(c["p"])
		var sub: Dictionary = c["win"] if won else c["lose"]
		extra_text = c["win_text"] if won else c["lose_text"]
		var r := apply_effects(sub)
		if r["battle"] != "":
			battle = r["battle"]
		if r["text"] != "":
			parts.append(r["text"])
	if eff.has("gold"):
		gold = maxi(0, gold + int(eff["gold"]))
		parts.append("%+d gold" % int(eff["gold"]))
	if eff.has("food"):
		food = maxi(0, food + int(eff["food"]))
		parts.append("%+d food" % int(eff["food"]))
	if eff.has("morale"):
		morale = clampi(morale + int(eff["morale"]), 0, 100)
		parts.append("%+d morale" % int(eff["morale"]))
	if eff.has("faith"):
		faith = clampi(faith + int(eff["faith"]), 0, 100)
		parts.append("%+d faith" % int(eff["faith"]))
	if eff.has("renown"):
		renown = maxi(0, renown + int(eff["renown"]))
		parts.append("%+d renown" % int(eff["renown"]))
	if eff.has("men"):
		var lost := _lose_men(int(eff["men"]), false)
		parts.append("-%d men" % lost)
	if eff.has("wounded"):
		var w := _lose_men(int(eff["wounded"]), true)
		parts.append("%d wounded" % w)
	if eff.has("recruit_men") and not squads.is_empty():
		var n := int(eff["recruit_men"])
		var s: Dictionary = squads[0]
		for sq in squads:
			if not unit(sq["type"])["cav"] and squad_max(sq) - int(sq["men"]) - int(sq["wounded"]) > 0:
				s = sq
				break
		s["men"] = int(s["men"]) + n
		parts.append("+%d men to %s" % [n, s["name"]])
	if eff.has("rep"):
		var rep: Dictionary = eff["rep"]
		for f in rep:
			change_rep(f, int(rep[f]))
			parts.append("%s %+d" % [f, int(rep[f])])
	if eff.has("days"):
		pass_days(int(eff["days"]))
		parts.append("%d days pass" % int(eff["days"]))
	if eff.has("battle"):
		battle = eff["battle"]
	_cleanup_squads()
	var text := ", ".join(parts)
	if extra_text != "":
		text = extra_text + ("\n(" + text + ")" if text != "" else "")
	return {"text": text, "battle": battle}


func _lose_men(n: int, as_wounded: bool) -> int:
	var done := 0
	for i in n:
		var candidates := []
		for s in squads:
			if int(s["men"]) > 0:
				candidates.append(s)
		if candidates.is_empty():
			break
		var s: Dictionary = candidates[rng.randi() % candidates.size()]
		s["men"] = int(s["men"]) - 1
		if as_wounded:
			s["wounded"] = int(s["wounded"]) + 1
		done += 1
	return done


func can_afford(req: Dictionary) -> bool:
	if req.has("gold") and gold < int(req["gold"]):
		return false
	if req.has("food") and food < int(req["food"]):
		return false
	return true


# ---------------------------------------------------------------- travel flow

func travel_to(idx: int) -> void:
	var from: Dictionary = nodes[current_node]
	var to: Dictionary = nodes[idx]
	var days := GameData.travel_days(from, to)
	pass_days(days)
	current_node = idx
	to["visited"] = true
	if is_wiped():
		goto("gameover")
		return
	battle_context = {}
	var ambush_chance := 0.4
	if not contract.is_empty() and contract["kind"] == "escort":
		ambush_chance = 0.5
	if rng.randf() < ambush_chance:
		var ev: Dictionary = GameData.ROAD_EVENTS[rng.randi() % GameData.ROAD_EVENTS.size()]
		goto("event", {"event": ev, "after": "enter"})
	else:
		enter_node()


func enter_node() -> void:
	var n: Dictionary = nodes[current_node]
	if is_wiped():
		goto("gameover")
		return
	# Contract business first.
	if not contract.is_empty() and int(contract["target"]) == current_node and not contract.get("done", false):
		if contract["kind"] == "hunt":
			var ev := {"id": "contract_hunt", "title": "Contract: " + str(contract["title"]),
				"text": "This is the place the %s's men spoke of. %s wait for you, and they have seen your banner." % [contract["faction"], GameData.ARMIES[contract["army"]]["name"]],
				"choices": [
					{"label": "Attack", "effects": {"battle": contract["army"]}, "text": "For God and for pay!"},
					{"label": "Not today", "effects": {}, "text": "You pull back. The days on the contract keep running."},
				]}
			battle_context = {"contract": true, "clear": current_node}
			goto("event", {"event": ev, "after": "settle"})
			return
		elif contract["kind"] == "escort":
			gold += int(contract["reward"])
			renown += 3
			change_rep(contract["faction"], 5)
			notice("The wagons reach %s safely. You are paid %d gold." % [n["name"], int(contract["reward"])])
			contract = {}
	settle_node()


## Resolve the node itself (no contract business).
func settle_node() -> void:
	var n: Dictionary = nodes[current_node]
	match n["kind"]:
		"camp":
			if not n["cleared"]:
				var ev: Dictionary = GameData.CAMP_EVENT.duplicate(true)
				ev["title"] = n["name"]
				battle_context = {"clear": current_node}
				goto("event", {"event": ev, "after": "map"})
				return
			goto("map")
		"ruins":
			if not n["cleared"]:
				var ev: Dictionary = GameData.RUIN_EVENT.duplicate(true)
				ev["title"] = n["name"]
				n["cleared"] = true
				goto("event", {"event": ev, "after": "map"})
				return
			goto("map")
		_:
			save_game()
			goto("town")


## Called by the event screen once the player picked a choice.
func resolve_choice(choice: Dictionary) -> Dictionary:
	var r := apply_effects(choice.get("effects", {}))
	var text: String = choice.get("text", "")
	if r["text"] != "":
		text = (text + "\n\n" if text != "" else "") + r["text"]
	r["text"] = text
	return r


func continue_after_event(after: String) -> void:
	if is_wiped():
		goto("gameover")
		return
	match after:
		"enter":
			enter_node()
		"settle":
			settle_node()
		"town":
			goto("town")
		_:
			battle_context = {}
			goto("map")


func start_battle(army: String, after: String) -> void:
	battle_context["army"] = army
	battle_context["after"] = after
	goto("battle", {"army": army})


## result: {victory: bool, losses: Array[int] per squad index, killed: int, kills: Array[int]}
func apply_battle_result(result: Dictionary) -> String:
	var lines := []
	var victory: bool = result["victory"]
	var wounded_share := 0.5 if victory else 0.25
	var losses: Array = result["losses"]
	var kills: Array = result["kills"]
	var total_dead := 0
	var total_wounded_new := 0
	for i in squads.size():
		var s: Dictionary = squads[i]
		var lost := int(losses[i]) if i < losses.size() else 0
		lost = mini(lost, int(s["men"]))
		var w := int(round(lost * wounded_share))
		s["men"] = int(s["men"]) - lost
		s["wounded"] = int(s["wounded"]) + w
		total_dead += lost - w
		total_wounded_new += w
		var before := squad_level(s)
		var k := int(kills[i]) if i < kills.size() else 0
		s["xp"] = int(s["xp"]) + (12 if victory else 4) + k
		if squad_level(s) > before:
			lines.append("%s are now veterans (rank %d)!" % [s["name"], squad_level(s)])
	lines.push_front("%d dead, %d wounded." % [total_dead, total_wounded_new])
	var army: Dictionary = GameData.ARMIES.get(battle_context.get("army", ""), {})
	if victory:
		var loot := int(army.get("loot", 50))
		loot = int(loot * rng.randf_range(0.8, 1.2))
		gold += loot
		renown += 2
		morale = clampi(morale + 8, 0, 100)
		lines.append("Victory! %d gold taken from the field." % loot)
		if battle_context.has("clear"):
			nodes[int(battle_context["clear"])]["cleared"] = true
			lines.append("%s is cleared." % nodes[int(battle_context["clear"])]["name"])
		if battle_context.get("contract", false) and not contract.is_empty():
			contract["done"] = true
			lines.append("Contract fulfilled - return to %s for payment." % nodes[int(contract["giver"])]["name"])
	else:
		morale = clampi(morale - 15, 0, 100)
		var lost_gold := int(gold * 0.15)
		var lost_food := int(food * 0.25)
		gold -= lost_gold
		food -= lost_food
		lines.append("Defeat. The baggage is plundered: -%d gold, -%d food." % [lost_gold, lost_food])
	_cleanup_squads()
	save_game()
	return "\n".join(lines)


func after_battle(victory: bool) -> void:
	var after: String = battle_context.get("after", "map")
	battle_context = {}
	if is_wiped():
		goto("gameover")
		return
	if victory and after in ["enter", "settle"]:
		var kind: String = nodes[current_node]["kind"]
		if kind in ["city", "town", "village", "monastery"]:
			if after == "enter":
				enter_node()
			else:
				goto("town")
			return
	goto("map")


# ---------------------------------------------------------------- towns

func offers_here() -> Array:
	var key := str(current_node)
	var offers: Array = town_contracts.get(key, [])
	var stale := offers.is_empty() or int(offers[0].get("made", 0)) < day - 6
	if stale:
		offers = _make_offers()
		town_contracts[key] = offers
	return offers


func _make_offers() -> Array:
	var here: Dictionary = nodes[current_node]
	var out := []
	var hunt_targets := []
	var escort_targets := []
	for n in nodes:
		if n["id"] == current_node:
			continue
		var d := Vector2(here["x"], here["y"]).distance_to(Vector2(n["x"], n["y"]))
		if d > 0.4:
			continue
		if n["kind"] == "camp" and not n["cleared"]:
			hunt_targets.append(n)
		elif n["kind"] in ["ruins", "village"]:
			hunt_targets.append(n)
		if n["kind"] in ["city", "town", "monastery"]:
			escort_targets.append(n)
	var fac: String = here["faction"]
	if fac == "":
		fac = "Holy See"
	if not hunt_targets.is_empty():
		var t: Dictionary = hunt_targets[rng.randi() % hunt_targets.size()]
		var army := "brigands_small"
		if t["kind"] == "camp":
			army = "brigands_large"
		elif t["kind"] == "ruins":
			army = "votaries" if rng.randf() < 0.5 else "scavengers"
		elif renown > 20 and rng.randf() < 0.35:
			army = "condottieri"
		elif rng.randf() < 0.4:
			army = "raiders"
		var dist := Vector2(here["x"], here["y"]).distance_to(Vector2(t["x"], t["y"]))
		var reward := int(GameData.ARMIES[army]["loot"] * 1.3 + dist * 400 + renown * 2)
		out.append({"kind": "hunt", "title": "Destroy the %s near %s" % [GameData.ARMIES[army]["name"].to_lower(), t["name"]],
			"target": t["id"], "army": army, "reward": reward, "days_left": int(dist * 40) + 8,
			"giver": current_node, "faction": fac, "made": day})
	if not escort_targets.is_empty():
		var t: Dictionary = escort_targets[rng.randi() % escort_targets.size()]
		var dist := Vector2(here["x"], here["y"]).distance_to(Vector2(t["x"], t["y"]))
		var reward := int(70 + dist * 450)
		out.append({"kind": "escort", "title": "Escort merchant wagons to %s" % t["name"],
			"target": t["id"], "army": "", "reward": reward, "days_left": int(dist * 30) + 5,
			"giver": current_node, "faction": fac, "made": day})
	return out


func accept_contract(c: Dictionary) -> void:
	contract = c.duplicate(true)
	contract["done"] = false
	var key := str(current_node)
	var offers: Array = town_contracts.get(key, [])
	offers.erase(c)


func collect_contract_here() -> String:
	if contract.is_empty() or not contract.get("done", false) or int(contract["giver"]) != current_node:
		return ""
	var r := int(contract["reward"])
	gold += r
	renown += 5
	change_rep(contract["faction"], 8)
	var t := "The %s pays you %d gold for '%s'. Renown and favour grow." % [contract["faction"], r, contract["title"]]
	contract = {}
	return t


func food_price() -> int:
	var k: String = nodes[current_node]["kind"]
	return 12 if k == "village" else 16


func recruits_here() -> Array:
	match nodes[current_node]["kind"]:
		"city":
			return ["sword", "spear", "xbow", "knight"]
		"town":
			return ["sword", "spear", "xbow"]
		"village":
			return ["spear"]
	return []


func price_mult() -> float:
	var f: String = nodes[current_node]["faction"]
	var rep := int(reputation.get(f, 0))
	return clampf(1.0 - rep / 200.0, 0.7, 1.4)


func hire_cost(type: String) -> int:
	return int(unit(type)["cost"] * unit(type)["size"] * price_mult())


func reinforce_cost() -> int:
	var c := 0.0
	for s in squads:
		var missing := squad_max(s) - int(s["men"]) - int(s["wounded"])
		if missing > 0:
			c += missing * unit(s["type"])["cost"]
	return int(c * price_mult())


func reinforce_all() -> void:
	for s in squads:
		var missing := squad_max(s) - int(s["men"]) - int(s["wounded"])
		if missing > 0:
			s["men"] = int(s["men"]) + missing


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"gold": gold, "food": food, "day": day, "morale": morale, "faith": faith, "renown": renown,
		"reputation": reputation, "squads": squads, "nodes": nodes, "current_node": current_node,
		"contract": contract, "town_contracts": town_contracts,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	rng.randomize()
	gold = int(data["gold"])
	food = int(data["food"])
	day = int(data["day"])
	morale = int(data["morale"])
	faith = int(data["faith"])
	renown = int(data["renown"])
	reputation = {}
	for k in data["reputation"]:
		reputation[k] = int(data["reputation"][k])
	squads = []
	for s in data["squads"]:
		squads.append({"type": s["type"], "name": s["name"], "men": int(s["men"]),
			"wounded": int(s["wounded"]), "xp": int(s["xp"])})
	nodes = []
	for n in data["nodes"]:
		var links := []
		for l in n["links"]:
			links.append(int(l))
		n["links"] = links
		n["id"] = int(n["id"])
		nodes.append(n)
	current_node = int(data["current_node"])
	contract = _fix_ints(data["contract"])
	town_contracts = {}
	for k in data.get("town_contracts", {}):
		var arr := []
		for c in data["town_contracts"][k]:
			arr.append(_fix_ints(c))
		town_contracts[k] = arr
	notices = []
	return true


func _fix_ints(c: Dictionary) -> Dictionary:
	for k in ["target", "reward", "days_left", "giver", "made"]:
		if c.has(k):
			c[k] = int(c[k])
	return c


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
