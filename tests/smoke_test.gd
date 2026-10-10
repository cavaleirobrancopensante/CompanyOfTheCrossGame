extends Node
## Headless smoke test: walks every screen, every event, every army, and a first-person fight.
## Run: godot --headless --path . res://tests/smoke_test.tscn

var main: Control


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	Game.new_game()
	for screen in ["town", "map", "company", "baggage", "title"]:
		Game.goto(screen)
		await _frames(4)
		print("screen ok: ", screen)
	Game.goto("squad", {"squad": 0})
	await _frames(4)
	Game.goto("character", {"squad": 0, "member": 0})
	await _frames(4)
	var mateo := Game.find_hero("Mateo 'Hammerhead'")
	print("Mateo: ", BX.describe(mateo), " THAC0 ", BX.thac0(mateo))
	var martin := Game.find_hero("Father Martin")
	print("Martin may use a spear? ", BX.can_use(martin, "spear"))
	# Equipment
	Game.add_item("chain", 3)
	var s1: Dictionary = Game.squads[1]
	print("outfitted with chain: ", Game.outfit_squad(s1, "chain"), "  squad AC now ", BX.group_stats(s1["members"])["ac"])
	print("load ", Game.load_cn(), " / ", Game.capacity_cn())
	# Every road event, every choice.
	for ev in GameData.ROAD_EVENTS:
		for c in ev["choices"]:
			Game.new_game()
			Game.goto("event", {"event": ev, "after": "map"})
			await _frames(3)
			var r := Game.resolve_choice(c)
			assert(r.has("text"))
	print("events ok")
	Game.new_game()
	var offers := Game.offers_here()
	Game.accept_contract(offers[0])
	for l in Game.nodes[Game.current_node]["links"]:
		Game.travel_to(int(l))
		await _frames(3)
		print("travelled to ", Game.nodes[Game.current_node]["name"], " day ", Game.day)
		break
	# Battles: run each army to the end.
	for army in GameData.ARMIES:
		Game.new_game()
		Game.battle_context = {"after": "map", "army": army}
		Game.goto("battle", {"army": army})
		await _frames(4)
		var b = main.current
		b._begin()
		b._all_attack()
		var steps := 0
		while b.phase != "over" and steps < 6000:
			b._step(0.05)
			steps += 1
		print("battle ", army, ": ", "WIN" if b.units.filter(func(u): return u["team"] == 1 and u["state"] == "ok").is_empty() else "LOSS", " after ", steps, " steps; men left ", Game.total_men(), " wounded ", Game.total_wounded())
		await _frames(2)
	# First-person: Mateo walks to the enemy and fights.
	Game.new_game()
	Game.battle_context = {"after": "map", "army": "brigands_small"}
	Game.goto("battle", {"army": "brigands_small"})
	await _frames(4)
	var bt = main.current
	bt._begin()
	bt._all_attack()
	bt.toggle_fps()
	print("fps on: ", bt.fps_mode, " hero ", bt.hero["c"]["name"])
	var steps2 := 0
	while bt.phase != "over" and steps2 < 4000:
		var e: int = bt._nearest_enemy(int(bt.hero["unit"]), 99999.0)
		if e >= 0 and not bt.hero["down"]:
			var to: Vector2 = bt.units[e]["pos"] - bt.hero["pos"]
			bt.hero["angle"] = to.angle()
			bt.hero["move"] = Vector2(0, -1)
			bt.hero_swing()
		bt._step(0.05)
		steps2 += 1
		if steps2 % 40 == 0:
			await _frames(1)
	print("fps battle over after ", steps2, " steps; hero felled ", bt.hero["kills"], ", hero hp ", bt.hero["c"]["hp"], ", down ", bt.hero["down"])
	await _frames(2)
	Game.save_game()
	print("load ok: ", Game.load_game(), " members in squad 0: ", Game.squads[0]["members"].size())
	Game.delete_save()
	print("SMOKE TEST DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
