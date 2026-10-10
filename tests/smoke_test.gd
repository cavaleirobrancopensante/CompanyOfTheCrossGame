extends Node
## Headless smoke test: walks every screen and runs a full battle.
## Run: godot --headless --path . res://tests/smoke_test.tscn

var main: Control


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.size = Vector2i(720, 1280)
	add_child(main)
	await _frames(5)
	Game.new_game()
	for screen in ["town", "map", "company", "title"]:
		Game.goto(screen)
		await _frames(4)
		print("screen ok: ", screen)
	# Every road event, every choice.
	for ev in GameData.ROAD_EVENTS:
		for c in ev["choices"]:
			Game.new_game()
			Game.goto("event", {"event": ev, "after": "map"})
			await _frames(3)
			var r := Game.resolve_choice(c)
			assert(r.has("text"))
	print("events ok")
	# Contracts in Rome.
	Game.new_game()
	var offers := Game.offers_here()
	print("offers: ", offers.size())
	Game.accept_contract(offers[0])
	# Travel along every road from Rome.
	for l in Game.nodes[Game.current_node]["links"]:
		Game.travel_to(int(l))
		await _frames(3)
		print("travelled to ", Game.nodes[Game.current_node]["name"], " day ", Game.day)
		break
	# Battles: run each army to the end at high speed.
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
		print("battle ", army, ": ", b.phase, " after ", steps, " steps; men left ", Game.total_men(), " wounded ", Game.total_wounded())
		await _frames(2)
	Game.save_game()
	print("load ok: ", Game.load_game())
	Game.delete_save()
	print("SMOKE TEST DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
