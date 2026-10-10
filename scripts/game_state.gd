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
var stash := {}   # baggage train: item id -> count
var mules := 0
var carts := 0

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
	var own := make_squad("sword", 18, "Mateo's Own")
	var mateo := BX.make("Fighter", 4, {"weapon": "war_hammer", "armor": "plate", "shield": "shield"}, "Mateo 'Hammerhead'")
	mateo["str"] = 17
	mateo["con"] = 15
	mateo["hero"] = true
	mateo["max_hp"] = 30
	mateo["hp"] = 30
	var martin := BX.make("Cleric", 3, {"weapon": "mace", "armor": "chain", "gear": ["holy_symbol", "holy_water"]}, "Father Martin")
	martin["wis"] = 16
	martin["hero"] = true
	own["members"].push_front(martin)
	own["members"].push_front(mateo)
	sync(own)
	squads.append(own)
	squads.append(make_squad("spear", 24))
	squads.append(make_squad("xbow", 14))
	stash = {"spear": 4, "shield": 2, "leather": 2, "dagger": 3, "holy_water": 1, "rope": 1}
	mules = 2
	carts = 0
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
	var u: Dictionary = GameData.UNITS[type]
	var members := []
	for i in men:
		var cls: String = u["cls"]
		var lvl := int(u["level"])
		if i == 0 and cls == "Normal Man":
			cls = "Fighter"  # every levy has a sergeant
			lvl = 1
		members.append(BX.make(cls, lvl, u["kit"]))
	var s := {"type": type, "name": squad_name, "members": members, "xp": 0}
	sync(s)
	return s


## Recount the cached men / wounded numbers from the character sheets.
func sync(s: Dictionary) -> void:
	var ok := 0
	var w := 0
	for c in s["members"]:
		if c["status"] == "ok":
			ok += 1
		elif c["status"] == "wounded":
			w += 1
	s["men"] = ok
	s["wounded"] = w


func sync_all() -> void:
	for s in squads:
		sync(s)


func members_with(s: Dictionary, status: String, heroes: bool = true) -> Array:
	var out := []
	for c in s["members"]:
		if c["status"] == status and (heroes or not c.get("hero", false)):
			out.append(c)
	return out


func wound(c: Dictionary) -> void:
	c["status"] = "wounded"
	c["hp"] = 0


func heal(c: Dictionary) -> void:
	c["status"] = "ok"
	c["hp"] = maxi(1, int(c["max_hp"]))


## Heal up to n wounded in a squad; returns how many.
func heal_squad(s: Dictionary, n: int) -> int:
	var w := members_with(s, "wounded")
	var k := mini(n, w.size())
	for i in k:
		heal(w[i])
	sync(s)
	return k


func find_hero(hero_name: String) -> Dictionary:
	for s in squads:
		for c in s["members"]:
			if c["name"] == hero_name:
				return c
	return {}


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
		# Wounded mend slowly on the road; the bruised regain 1d3 hp a day (B/X rest).
		var cure_slots := 0
		for s in squads:
			for c in s["members"]:
				if c["status"] == "ok" and c["cls"] == "Cleric" and int(c["level"]) >= 2:
					cure_slots += 1
		for s in squads:
			for c in s["members"]:
				if c["status"] == "wounded":
					if rng.randf() < 0.08:
						heal(c)
					elif cure_slots > 0:
						cure_slots -= 1  # Father Martin's Cure Light Wounds
						heal(c)
				elif c["status"] == "ok" and int(c["hp"]) < int(c["max_hp"]):
					c["hp"] = mini(int(c["max_hp"]), int(c["hp"]) + BX.d(3))
			sync(s)
		# Morale drifts toward a level set by faith.
		var target := 45 + faith / 4
		if morale < target:
			morale += 1
		elif morale > target:
			morale -= 1
		if morale < 20 and total_men() > 0:
			var s: Dictionary = squads[rng.randi() % squads.size()]
			var pool := members_with(s, "ok", false)
			var lost := mini(maxi(1, int(pool.size() * 0.1)), pool.size())
			for k in lost:
				s["members"].erase(pool[k])
			sync(s)
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
	sync_all()
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
			if not unit(sq["type"])["cav"] and squad_max(sq) - int(sq["members"].size()) > 0:
				s = sq
				break
		for k in n:
			s["members"].append(BX.make("Normal Man", 0, unit(s["type"])["kit"]))
		sync(s)
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
			for c in members_with(s, "ok", false):
				candidates.append([s, c])
		if candidates.is_empty():
			break
		var pick: Array = candidates[rng.randi() % candidates.size()]
		if as_wounded:
			wound(pick[1])
		else:
			pick[0]["members"].erase(pick[1])
		sync(pick[0])
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
	var days := travel_days_to(idx)
	if overloaded():
		notice("The baggage is too heavy: the march is slow.")
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


## result: {victory, losses: Array[int] per squad index, kills: Array[int], enemy_dead: int}
func apply_battle_result(result: Dictionary) -> String:
	var lines := []
	var level_msgs := []
	var victory: bool = result["victory"]
	var wounded_share := 0.5 if victory else 0.25
	var losses: Array = result["losses"]
	var kills: Array = result["kills"]
	var enemy_dead := int(result.get("enemy_dead", 0))
	var total_dead := 0
	var total_wounded_new := 0
	for i in squads.size():
		var s: Dictionary = squads[i]
		var lost := int(losses[i]) if i < losses.size() else 0
		# The men fall first; heroes only go down when the squad is broken, and never die.
		var pool := members_with(s, "ok", false)
		pool.shuffle()
		var heroes := members_with(s, "ok", true).filter(func(c): return c.get("hero", false))
		for k in mini(lost, pool.size() + heroes.size()):
			if k < pool.size():
				var c: Dictionary = pool[k]
				var save_chance := wounded_share + BX.mod(int(c["con"])) * 0.05
				if rng.randf() < save_chance:
					wound(c)
					total_wounded_new += 1
				else:
					s["members"].erase(c)
					total_dead += 1
			else:
				var h: Dictionary = heroes[k - pool.size()]
				wound(h)
				total_wounded_new += 1
				lines.append("%s is carried wounded from the field." % h["name"])
		sync(s)
		var before := squad_level(s)
		var k := int(kills[i]) if i < kills.size() else 0
		s["xp"] = int(s["xp"]) + (12 if victory else 4) + k
		if squad_level(s) > before:
			lines.append("%s are now veterans (rank %d)!" % [s["name"], squad_level(s)])
		# B/X experience: a share for every survivor, more for heroes.
		var per_man := (10 if victory else 3) + int(k * 10.0 / maxf(1.0, s["members"].size()))
		for c in s["members"]:
			if c["status"] == "ok":
				var gain := per_man * (5 if c.get("hero", false) else 1) + (enemy_dead * 5 if c.get("hero", false) else 0)
				var m := BX.gain_xp(c, gain)
				if m != "":
					level_msgs.append(m)
	lines.push_front("%d dead, %d wounded." % [total_dead, total_wounded_new])
	var army: Dictionary = GameData.ARMIES.get(battle_context.get("army", ""), {})
	if victory:
		var loot := int(army.get("loot", 50))
		loot = int(loot * rng.randf_range(0.8, 1.2))
		gold += loot
		renown += 2
		morale = clampi(morale + 8, 0, 100)
		lines.append("Victory! %d gold taken from the field." % loot)
		var pool_items: Array = GameData.LOOT_ITEMS.get(battle_context.get("army", ""), [])
		var got := []
		for k in mini(1 + enemy_dead / 8, 6):
			if pool_items.is_empty():
				break
			var it: String = pool_items[rng.randi() % pool_items.size()]
			add_item(it)
			got.append(BX.ITEMS[it]["name"])
		if not got.is_empty():
			lines.append("Gear stripped from the fallen: " + ", ".join(got) + ".")
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
	if level_msgs.size() > 4:
		var extra := level_msgs.size() - 4
		level_msgs = level_msgs.slice(0, 4)
		level_msgs.append("...and %d more advance." % extra)
	lines.append_array(level_msgs)
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
		var missing := squad_max(s) - int(s["members"].size())
		if missing > 0:
			c += missing * unit(s["type"])["cost"]
	return int(c * price_mult())


func reinforce_all() -> void:
	for s in squads:
		var missing := squad_max(s) - int(s["members"].size())
		var u := unit(s["type"])
		for i in maxi(0, missing):
			s["members"].append(BX.make(u["cls"], int(u["level"]), u["kit"]))
		sync(s)


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"gold": gold, "food": food, "day": day, "morale": morale, "faith": faith, "renown": renown,
		"reputation": reputation, "squads": squads, "nodes": nodes, "current_node": current_node,
		"contract": contract, "town_contracts": town_contracts,
		"stash": stash, "mules": mules, "carts": carts,
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
		var members := []
		for c in s.get("members", []):
			for k in ["level", "xp", "hp", "max_hp", "str", "int", "wis", "dex", "con", "cha"]:
				c[k] = int(c[k])
			var gear := []
			for g in c.get("gear", []):
				gear.append(str(g))
			c["gear"] = gear
			members.append(c)
		var sq := {"type": s["type"], "name": s["name"], "members": members, "xp": int(s["xp"])}
		sync(sq)
		squads.append(sq)
	stash = {}
	for k in data.get("stash", {}):
		stash[k] = int(data["stash"][k])
	mules = int(data.get("mules", 0))
	carts = int(data.get("carts", 0))
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


# ---------------------------------------------------------------- baggage

func add_item(item: String, n: int = 1) -> void:
	stash[item] = int(stash.get(item, 0)) + n


func take_item(item: String) -> bool:
	if int(stash.get(item, 0)) <= 0:
		return false
	stash[item] = int(stash[item]) - 1
	if int(stash[item]) <= 0:
		stash.erase(item)
	return true


func capacity_cn() -> int:
	return BX.BASE_CN + mules * BX.MULE_CN + carts * BX.CART_CN


func load_cn() -> int:
	var t := food * BX.FOOD_CN
	for k in stash:
		t += int(BX.ITEMS[k]["cn"]) * int(stash[k])
	return t


func overloaded() -> bool:
	return load_cn() > capacity_cn()


func travel_days_to(idx: int) -> int:
	var d := GameData.travel_days(nodes[current_node], nodes[idx])
	if overloaded():
		d = int(ceil(d * 1.5))
	return d


## Put an item from the baggage on a character. Returns "" or the reason it failed.
func equip(c: Dictionary, item: String) -> String:
	if int(stash.get(item, 0)) <= 0:
		return "None left in the baggage."
	var why := BX.can_use(c, item)
	if why != "":
		return why
	var it: Dictionary = BX.ITEMS[item]
	var slot: String = it["slot"]
	take_item(item)
	if slot == "gear":
		c["gear"].append(item)
		return ""
	if c.get(slot, "") != "":
		add_item(c[slot])
	c[slot] = item
	if it.get("two_handed", false) and c.get("shield", "") != "":
		add_item(c["shield"])
		c["shield"] = ""
	return ""


func unequip(c: Dictionary, slot: String, gear_index: int = -1) -> void:
	if slot == "gear":
		if gear_index >= 0 and gear_index < c["gear"].size():
			add_item(c["gear"][gear_index])
			c["gear"].remove_at(gear_index)
		return
	if c.get(slot, "") != "":
		add_item(c[slot])
		c[slot] = ""


## Give everyone in a squad who lacks a better piece this item, while stock lasts.
func outfit_squad(s: Dictionary, item: String) -> int:
	var it: Dictionary = BX.ITEMS[item]
	var slot: String = it["slot"]
	var n := 0
	for c in s["members"]:
		if int(stash.get(item, 0)) <= 0:
			break
		if c.get(slot, "") == item:
			continue
		if slot == "armor" and c.get("armor", "") != "" and int(BX.ITEMS[c["armor"]]["ac"]) <= int(it["ac"]):
			continue
		if equip(c, item) == "":
			n += 1
	return n


func item_price(item: String) -> int:
	return maxi(1, int(BX.ITEMS[item]["gp"] * price_mult()))


func sell_price(item: String) -> int:
	return maxi(1, int(BX.ITEMS[item]["gp"] / 2))
