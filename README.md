# Company of the Cross — the game

A mobile strategy game set in the world of *The Company of the Cross*: Anno Domini 2987, the Papal States, a thousand years after the Fall. You are Captain Mateo "Hammerhead", with Father Martin as chaplain, leading a free company under the Cross.

The mix it aims for: **Mount & Blade** (a company you pay, feed and grow), **Total War / Sword & Banner** (tactical field battles with morale and rout), **Crusader Kings** (standing with the powers of Italy), and **The Curious Expedition** (travel days, supplies and choice-driven road events).

Built in **Godot 4.7**, portrait 720×1280, GL Compatibility renderer, everything drawn in code — no art assets needed yet.

## What's new in 1.1

- **B/X D&D under the hood.** Every man in the company has a character sheet: 3d6 abilities with B/X modifiers, class (Fighter, Cleric, Normal Man), level, XP, hit points, AC, THAC0 and saving throws. Normal Men who survive long enough become 1st-level Fighters. Father Martin is a Cleric: blunt weapons only, and from level 2 his Cure Light Wounds raises a wounded man every day.
- **Inventory.** Weapon, missile, armour, shield and gear slots per man, B/X prices and weights. Equip one man from his sheet, or give a whole squad chain mail at once from the squad screen.
- **Baggage train.** Mules (2000 cn) and carts (4000 cn) carry the stash and the food. Overload it and every march takes half again as long. Buy them in town stables; buy and sell gear in the armoury; strip gear from the fallen after a victory.
- **Battles use the sheets.** A squad's average AC, THAC0, damage and hit points decide how fast it kills and dies.
- **First-person mode.** Tap *First person* in battle to step out of the formation as Mateo (or your best fighter) and fight with your own hands, using the fake-3D trick from MechFPS: left thumb walks, right thumb looks, STRIKE rolls a real d20 against the enemy's AC. *TO ME!* calls your squad to you; *TACTICAL* switches back. The battle never pauses: both views show the same fight. On a phone, battles turn the screen to landscape.

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
scripts/bx.gd               B/X rules: classes, AC, THAC0, XP, items
scripts/game_data.gd        unit stats, enemy armies, map, events (edit this to tune/add content)
scripts/ui.gd               theme + UI builders
scripts/screens/*.gd        title, map (+ map_view), town, event, battle (+ fps_view), company,
                            squad, character sheet, baggage, game over
tests/smoke_test.tscn       headless test: every screen, every event, every army
```

Run the smoke test on a PC: `godot --headless --path . res://tests/smoke_test.tscn`

## Roadmap ideas

1. Rival companies and lords moving on the map; sieges.
2. Named heroes (Mateo, Martin, sergeants) with traits — the monastic assessment system from the novel.
3. Formations and flanking in battle; terrain (hills, woods, rivers).
4. Faction politics: papal favour, excommunication, marriages and feuds (the Crusader Kings layer).
5. Pixel art and music.
