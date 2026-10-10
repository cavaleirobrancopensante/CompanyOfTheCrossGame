# Company of the Cross — the game

A mobile strategy game set in the world of *The Company of the Cross*: Anno Domini 2987, the Papal States, a thousand years after the Fall. You are Captain Mateo "Hammerhead", with Father Martin as chaplain, leading a free company under the Cross.

The mix it aims for: **Mount & Blade** (a company you pay, feed and grow), **Total War / Sword & Banner** (tactical field battles with morale and rout), **Crusader Kings** (standing with the powers of Italy), and **The Curious Expedition** (travel days, supplies and choice-driven road events).

Built in **Godot 4.7**, portrait 720×1280, GL Compatibility renderer, everything drawn in code — no art assets needed yet.

## What's in version 1.0a

- **Campaign map of Italy** — 28 places (cities, towns, villages, monasteries, Old World ruins, brigand holds) joined by roads. Marching takes days; every day eats food and wages.
- **The company** — up to 6 squads: Sergeants, Spearmen, Crossbowmen, Knights. Men get wounded and recover, squads gain veteran ranks (★). Hunger, unpaid wages and low morale cause desertion.
- **Faith and morale** — Mass with Father Martin, monastery blessings; faith sets the level morale settles at.
- **Road events** — 12 events (the hermit, the Voice in the Station, Votaries of the Engine, relic peddler, deserters…) plus ruins to search and brigand holds to storm.
- **Contracts** — hunt contracts (destroy a warband, return to the giver for pay) and escort contracts, with deadlines. Reputation with the Holy See, Venice, Milan and Naples changes prices.
- **Battles** — deploy in the gold zone, then tap a squad and tap ground (move) or an enemy (attack). Spearmen beat horse, knights get a charge bonus, crossbows shoot from range, broken squads rout and shake their neighbours.
- **Autosave** on entering a settlement and after battles.

## Project layout

```
scenes/main.tscn            root scene (just a script)
scripts/game_state.gd       autoload "Game": campaign state, rules, save/load, screen flow
scripts/game_data.gd        unit stats, enemy armies, map, events (edit this to tune/add content)
scripts/ui.gd               theme + UI builders
scripts/screens/*.gd        title, map (+ map_view), town, event, battle, company, game over
tests/smoke_test.tscn       headless test: every screen, every event, every army
```

Run the smoke test on a PC: `godot --headless --path . res://tests/smoke_test.tscn`

## Roadmap ideas

1. Rival companies and lords moving on the map; sieges.
2. Named heroes (Mateo, Martin, sergeants) with traits — the monastic assessment system from the novel.
3. Formations and flanking in battle; terrain (hills, woods, rivers).
4. Faction politics: papal favour, excommunication, marriages and feuds (the Crusader Kings layer).
5. Pixel art and music.
