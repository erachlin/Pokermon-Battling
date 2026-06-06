# Elemental Editions Mechanics Map

This document is the maintainer-facing map for the live `ElementalEditions` mod.

Use it when you want to answer three questions:

1. Where is a mechanic implemented?
2. What else must be updated to change it safely?
3. Where should that mechanic be explained to the player in game?

This is written against the active mod folder:

- `Balatro/mods/ElementalEditions`

It does not describe `third_party/Pokermon` internals except where this mod deliberately plugs into them.

## 1. Core Repo Map

These files are the main system hubs:

| Area | Main files |
| --- | --- |
| Boot / config / helpers | `main.lua`, `config.lua`, `elemental_editions.json`, `functions/constants.lua` |
| Debug / crash tracing | `functions/debug.lua`, `functions/run_hooks.lua` |
| Element detection and hand summaries | `functions/element_channels.lua`, `functions/pokermon_bridge.lua` |
| Pokemon HP / KO | `functions/pokemon_hp.lua` |
| Joker statuses and status visuals | `functions/joker_status.lua`, `functions/ui_status.lua` |
| Damage pipeline and status application | `functions/pressure_damage.lua`, `functions/feedback.lua` |
| Boss pressure / trainer boss behavior | `functions/boss_hooks.lua`, `functions/trainer_battles.lua` |
| Challenge decks and challenge registration | `functions/challenge_framework.lua`, `challenges/*.lua` |
| Battle deck / battle mode | `backs/backs1.lua`, `functions/battle_mode.lua` |
| Elemental card creation or spread | `functions/card_creation.lua` |
| Pokemon runtime overrides | `functions/pokemon_overrides.lua`, `balance/elemental_pokemon_overrides.lua` |
| Custom edition definitions | `editions/fire.lua`, `editions/water.lua`, `editions/earth.lua`, `editions/lightning.lua` |
| Singed card-state logic | `enhancements/battle_status_cards.lua` |
| Tooltips / localization | `functions/ui_status.lua`, `localization/en-us.lua` |
| Compatibility / legacy repairs | `functions/runtime_compat.lua`, `main.lua` |

## 2. Safe Change Rule

For almost every gameplay change in this mod, there are four layers:

1. Mechanical logic
2. Balance constants and config
3. Player-facing explanation
4. Debug / test visibility

If you only change layer 1, the mod often still "works", but it becomes misleading or fragile.

When changing a mechanic, check these surfaces:

- Logic: the main function that performs the mechanic
- Config: `config.lua`
- Localization: `localization/en-us.lua`
- Tooltip/UI: `functions/ui_status.lua`, challenge `loc_txt`, back descriptions, or popup messaging in `functions/feedback.lua`
- Debug: `functions/debug.lua` and any relevant `debug.*` calls in the system you touched

## 3. Element Vocabulary

`functions/constants.lua` is the semantic center of the mod.

Important tables there:

- `ElementalEditions.constants.element_keys`
- `ElementalEditions.constants.elements`
- `ElementalEditions.constants.type_aliases`
- `ElementalEditions.constants.status_keys`
- `ElementalEditions.constants.status_to_element`
- `ElementalEditions.constants.tracked_counters`
- `ElementalEditions.constants.hand_key_by_name`

If you add or rename an element, status, counter, or hand mapping, start here first.

Also update:

- `config.lua`
- `localization/en-us.lua`
- any edition file or challenge file that references that key

## 4. Elemental Pressure

### What "pressure" means

In this mod, "pressure" means a playing card is treated as an elemental battlefield source and can:

- be counted as an elemental channel
- deal damage to Pokemon Jokers
- apply or cleanse statuses
- be used by bosses, trainers, and Pokemon overrides

Pressure is not one single file. It is a shared concept used by several systems.

### Where pressure is detected

Primary files:

- `functions/element_channels.lua`
- `functions/pokermon_bridge.lua`

Primary functions:

- `ElementalEditions.get_card_element(card)`
- `ElementalEditions.get_scored_element_channels(context)`
- `ElementalEditions.get_held_element_channels(context)`
- `ElementalEditions.has_flower_channel(card)`

### Safe update checklist

If you change what counts as elemental pressure, update all of these together:

- `functions/constants.lua`
- `functions/element_channels.lua`
- `functions/card_creation.lua`
- `functions/pressure_damage.lua`
- `config.lua`
- `localization/en-us.lua`
- challenge text in `challenges/*.lua` if the change alters how a challenge deck is supposed to behave

### Where to explain it in game

Current explanation surfaces:

- elemental edition descriptions in `localization/en-us.lua`
- status tooltip rows in `functions/ui_status.lua`
- challenge descriptions in `challenges/*.lua`
- battle deck description in `localization/en-us.lua`
- popup summaries in `functions/feedback.lua`

If you want a clearer generic explanation of pressure, the safest places are:

- `localization/en-us.lua`
- challenge `loc_txt`
- `functions/ui_status.lua`

## 5. Grass Pressure

### What Grass pressure is

Grass pressure is not a custom edition.

Right now, Grass pressure means:

- a playing card has Pokermon's Flower enhancement
- the mod reads that card as `element_key = "grass"`

This is why Flower cards work but there is no separate Grass edition shader.

### Where Grass pressure is defined

Files and functions:

- `functions/constants.lua`
  - `elements.grass`
  - `elements.grass.enhancement = "m_poke_flower"`
- `functions/pokermon_bridge.lua`
  - `has_flower_channel(card)`
- `functions/element_channels.lua`
  - `get_card_element(card)` returns `"grass"` for Flower cards
- `functions/card_creation.lua`
  - `apply_element_to_card(card, "grass")` uses `card:set_ability(G.P_CENTERS.m_poke_flower, nil, true)`
- `functions/pressure_damage.lua`
  - Grass participates in damage, statuses, cleansing, and summaries like any other element
- `functions/joker_status.lua`
  - Grass maps to the `asleep` status through `status_to_element`

### What "Grass pressure spreads" means

When the mod says Grass pressure spreads, it means the mod converts another normal playing card into a Flower card.

The spread path is:

- `functions/trainer_battles.lua`
  - `maybe_transform_for_boss(...)`
- `functions/card_creation.lua`
  - `transform_random_card_to_element("grass", ...)`
  - `apply_element_to_card(card, "grass")`

Some Pokemon override effects can also spread or transform cards:

- `balance/elemental_pokemon_overrides.lua`
- called through `functions/pokemon_overrides.lua`

### Safe update checklist

If you change Grass pressure, update all of these together:

- `functions/constants.lua`
- `functions/pokermon_bridge.lua`
- `functions/element_channels.lua`
- `functions/card_creation.lua`
- `functions/pressure_damage.lua`
- `config.lua -> effectiveness.grass`, `messages.flavor.grass`, and any relevant status values
- `localization/en-us.lua`
- challenge text for Erika or any other Grass-heavy content

### Where it should be explained in game

Grass pressure is now explained in-game in two places.

Current explanation surfaces:

- Erika challenge text
- Asleep tooltip text
- popup flavor text

If you want players to understand Grass pressure more clearly, the safest places to add that explanation are:

- `localization/en-us.lua`
- `functions/ui_status.lua`
- `challenges/challenge_005_erika.lua`

Flower now has a dedicated ElementalEditions tooltip append path through `functions/ui_status.lua`, which wraps the `m_poke_flower` center and adds Grass-pressure explanation lines without editing Pokermon itself.

## 6. Custom Elemental Editions

Fire, Water, Earth, and Lightning are custom editions with shaders and small score flavor effects.

Files:

- `editions/fire.lua`
- `editions/water.lua`
- `editions/earth.lua`
- `editions/lightning.lua`
- shader assets under `assets/shaders/`
- edition text in `localization/en-us.lua`

Key responsibilities:

- register shader with `SMODS.Shader`
- register edition with `SMODS.Edition`
- provide `loc_vars`
- provide `calculate`

### Important implementation note

These edition calculations must use playing-card edition scoring contexts safely.

Current shared helper:

- `main.lua`
  - `ElementalEditions.is_playing_card_edition_context(card, context)`

If you change edition scoring behavior, use that helper or update it deliberately.

### Safe update checklist

If you change an edition:

- update that edition file
- update `config.lua -> pressure`
- update `localization/en-us.lua`
- confirm `functions/element_channels.lua` still recognizes the edition key
- confirm `main.lua -> get_edition_center_key` and `card_has_edition` still match the edition key you use
- keep `functions/runtime_compat.lua` in mind if you rename edition IDs

## 7. Elemental Damage Pipeline

This is the main battlefield-pressure pipeline.

Primary file:

- `functions/pressure_damage.lua`

Key entry points:

- `apply_elemental_damage_from_scored_cards(context)`
- `apply_elemental_damage_from_discard_context(context)`
- `apply_elemental_pressure_from_held_cards(context)`
- `apply_elemental_damage_from_scored_card(...)`
- `apply_elemental_damage_from_discarded_card(...)`
- `apply_elemental_damage_to_targets(...)`
- `calculate_elemental_damage(...)`
- `get_eligible_pokemon_targets(context)`

Where it is called:

- `functions/run_hooks.lua`

### Safe update checklist

If you change scored/discard/held damage behavior:

- update `functions/pressure_damage.lua`
- update `config.lua -> damage`
- update `functions/feedback.lua` if the message wording or aggregation should change
- update `functions/run_hooks.lua` if the trigger timing changes
- update `README.md` and any challenge text if the mechanic meaning changes

### If you change target behavior

Also review:

- `functions/pokemon_hp.lua`
- `functions/pokermon_bridge.lua`
- `functions/pokemon_overrides.lua`

## 8. Type Effectiveness

Type effectiveness is a separate layer that modifies elemental damage after an element is identified and before damage is applied.

Files:

- `functions/pokermon_bridge.lua`
- `config.lua -> effectiveness`
- `functions/constants.lua -> type_aliases`

Key functions:

- `get_pokemon_type(card)`
- `get_pokemon_types(card)`
- `get_primary_pokemon_type(card)`
- `get_element_attack_type(element_key)`
- `get_type_multiplier_against_types(element_key, type_list)`
- `get_type_multiplier(element_key, pokemon_card)`
- `format_effectiveness_message(multiplier)`

### Safe update checklist

If you change type matchups:

- update `config.lua -> effectiveness`
- update `config.lua -> damage.same_type_resist`, `lightning_ground_multiplier`, `earth_bird_multiplier`, min/max clamps if relevant
- update `functions/constants.lua -> type_aliases` if you introduce a new alias or rename a type
- verify `functions/pokermon_bridge.lua` still normalizes correctly
- update player-facing wording in `localization/en-us.lua` only if meaning changed, not just numbers

### Where it is explained in game

Current surfaces:

- popup summaries in `functions/feedback.lua`
- localization keys:
  - `elem_super_effective`
  - `elem_resisted`
  - `elem_no_effect`

There is not currently a big full type-chart UI in game. If you want one, add it separately rather than overloading status tooltips.

## 9. Pokemon HP, KO, and Revive

Primary file:

- `functions/pokemon_hp.lua`

Key functions:

- `get_pokemon_hp_max`
- `init_pokemon_hp`
- `get_pokemon_hp`
- `set_pokemon_hp`
- `damage_pokemon`
- `heal_pokemon`
- `is_pokemon_knocked_out`
- `knock_out_pokemon`
- `revive_pokemon`
- `refresh_pokemon_team`

Where KO is enforced:

- `functions/run_hooks.lua`
  - `handle_set_debuff(card)`

Where it is shown:

- `functions/ui_status.lua`
- `localization/en-us.lua`
- `functions/feedback.lua`

### Safe update checklist

If you change HP or KO:

- update `functions/pokemon_hp.lua`
- update `config.lua -> hp`
- update tooltip text in `functions/ui_status.lua`
- update localization strings in `localization/en-us.lua`
- verify `functions/run_hooks.lua -> handle_set_debuff` still matches the intended KO behavior

## 10. Joker Statuses

Primary file:

- `functions/joker_status.lua`

Key functions:

- `get_joker_status`
- `apply_joker_status`
- `clear_joker_status`
- `status_prevents_trigger`
- `modify_pokemon_ability_by_status`
- `modify_elemental_damage_by_status`
- `tick_joker_statuses`
- `refresh_status_visuals`
- `install_joker_wrapper`

Status storage:

- `card.ability.extra.elem_status`

Status visual storage:

- `card.ability.extra.elem_status_visual`

### Safe update checklist

If you change a status:

- update `functions/joker_status.lua`
- update `config.lua -> status`
- update `functions/constants.lua -> status_keys` or `status_to_element` if the mapping changed
- update `functions/pokemon_overrides.lua` if the status has override-side bonuses or hooks
- update `functions/ui_status.lua`
- update `localization/en-us.lua`

### Current statuses

- Burned
- Paralyzed
- Dazed
- Confused
- Asleep

Each status currently has:

- a mechanical effect
- a player-visible name
- tooltip text
- optional visual transform

## 11. Status Visual Editions

This is a sub-system of statuses, but it is important enough to track separately because it touches Joker edition safety.

Primary file:

- `functions/joker_status.lua`

Key functions:

- local `capture_edition_snapshot`
- local `restore_edition_snapshot`
- local `apply_status_visual`
- local `clear_status_visual`
- exported:
  - `ElementalEditions.apply_status_visual`
  - `ElementalEditions.clear_status_visual`

Current mapping:

- Burned -> Fire visual
- Paralyzed -> Lightning visual
- Dazed -> Earth visual
- Confused -> Water visual
- Asleep -> text/status only

Config that controls this:

- `config.lua -> gameplay.enable_status_edition_transforms`
- `config.lua -> gameplay.enable_status_edition_visuals`
- `config.lua -> gameplay.status_editions_visual_only`
- `config.lua -> gameplay.preserve_existing_joker_editions`
- `config.lua -> gameplay.status_visuals_overwrite_existing_editions`

### Safe update checklist

If you change status visuals:

- update `functions/joker_status.lua`
- update `functions/constants.lua -> status_to_element` if mapping changes
- update `config.lua`
- update `localization/en-us.lua` if the player-visible meaning changed
- keep `main.lua -> get_edition_center_key` and `card_has_edition` compatible with any new visual edition you use

## 12. Singed Card State

Singed is intentionally separate from Joker statuses.

It is a playing-card state, not a Pokemon Joker state.

Primary file:

- `enhancements/battle_status_cards.lua`

Key functions:

- `can_receive_singed`
- `apply_singed`

Where it is caused:

- `functions/pressure_damage.lua`
  - `apply_singed_from_fire(...)`

Balance:

- `config.lua -> card_status`

Player-facing:

- edition text in `localization/en-us.lua`

### Important note

There is also a legacy file:

- `editions/singed.lua`

That file is not part of the active load list in `main.lua`. Treat it as historical unless you deliberately decide to restore or delete it.

### Safe update checklist

If you change Singed:

- update `enhancements/battle_status_cards.lua`
- update `functions/pressure_damage.lua` if the application trigger changes
- update `config.lua -> card_status`
- update `localization/en-us.lua`
- do not mix it into Joker Burned unless you intentionally redesign both systems together

## 13. Messages, Popups, and Readability

Primary files:

- `main.lua`
  - `show_status_text`
  - `show_status`
- `functions/feedback.lua`
- `functions/trainer_battles.lua`

Config:

- `config.lua -> gameplay.enable_damage_messages`
- `config.lua -> gameplay.message_verbosity`
- `config.lua -> messages.*`

Key message functions:

- `get_message_delay`
- `should_show_individual_damage`
- `show_damage_message`
- `show_effectiveness_summary`
- `show_aoe_damage_summary`
- `show_ability_trigger_message`
- trainer `announce(...)`

### Safe update checklist

If you change popup timing or spam behavior:

- update `functions/feedback.lua`
- update `main.lua -> show_status_text` if the underlying popup format changes
- update `functions/trainer_battles.lua` for boss intro timing
- update `config.lua -> messages`

## 14. Tooltips and In-Game Explanations

Primary files:

- `functions/ui_status.lua`
- `localization/en-us.lua`
- `challenges/*.lua`
- `backs/backs1.lua`

What each one explains:

- `ui_status.lua`
  - HP
  - KO
  - active status
  - override summary
  - counters
- `localization/en-us.lua`
  - edition descriptions
  - status names
  - status explanatory lines
  - challenge names
  - deck description
- `challenges/*.lua`
  - challenge-specific mechanical framing
- `backs/backs1.lua`
  - battle deck summary

### Safe update checklist

If a mechanic changes meaning, do not stop at the logic file.

Update:

- `localization/en-us.lua`
- `functions/ui_status.lua`
- challenge `loc_txt` if the mechanic is trainer-specific
- `README.md` if the change affects how the mod is supposed to be read globally

## 15. Trainer Challenges

Primary files:

- `functions/challenge_framework.lua`
- `functions/trainer_battles.lua`
- `challenges/challenge_001_youngster.lua`
- `challenges/challenge_002_brock.lua`
- `challenges/challenge_003_misty.lua`
- `challenges/challenge_004_surge.lua`
- `challenges/challenge_005_erika.lua`

What lives where:

- `challenge_framework.lua`
  - build challenge deck preview cards
  - load challenge definition files
  - register SMODS challenges
- each `challenge_*.lua`
  - trainer identity
  - `starter_distribution`
  - `growth_distribution`
  - `boss_sequence`
  - challenge `loc_txt`
  - starting Jokers and items
- `trainer_battles.lua`
  - runtime activation
  - boss display name
  - per-ante boss selection
  - boss spread behavior

### Safe update checklist

If you change a trainer challenge:

- update that challenge file
- update `functions/challenge_framework.lua` only if deck-building structure changed
- update `functions/trainer_battles.lua` if the runtime boss behavior changed
- update `localization/en-us.lua` only if the challenge name or generic dictionary text changed

## 16. Challenge Starting Decks and Deck Viewer

Primary file:

- `functions/challenge_framework.lua`

Key function:

- `build_elemental_challenge_deck(distribution, deck_type)`

This is what makes elemental/Flower starter cards visible in the challenge deck viewer before the run begins.

Important behavior:

- Fire/Water/Earth/Lightning are written to card proto field `d`
- Grass writes Pokermon's Flower enhancement to proto field `e`

### Safe update checklist

If challenge deck preview stops matching runtime behavior:

- check `functions/challenge_framework.lua`
- check `functions/runtime_compat.lua`
- check trainer `starter_distribution`
- check `functions/trainer_battles.lua -> activate_trainer_battle(... starter_seeded = true)`

## 17. Battle Mode and the Elemental Battle Deck

Primary files:

- `backs/backs1.lua`
- `functions/battle_mode.lua`

What they do:

- register the custom deck
- activate battle mode
- schedule starter elemental seeding
- apply ante growth pressure

Key functions:

- `activate_battle_mode`
- `infuse_element_set`
- `infuse_element_distribution`
- `handle_battle_mode_setting_blind`
- `schedule_battle_mode_seed`
- `seed_battle_mode_now`

### Safe update checklist

If you change the custom deck:

- update `backs/backs1.lua`
- update `functions/battle_mode.lua`
- update `localization/en-us.lua`
- update `config.lua -> battle_mode`

## 18. Boss Pressure and Boss Blind Naming

There are two separate boss systems here.

### A. Generic boss status pressure

Primary file:

- `functions/boss_hooks.lua`

Key function:

- `apply_boss_status_pressure(context)`

This applies a status to a target Pokemon Joker at blind start.

### B. Trainer boss identity and boss spread behavior

Primary file:

- `functions/trainer_battles.lua`

Key functions:

- `handle_trainer_battle_setting_blind`
- `handle_trainer_battle_context`
- `get_boss_damage_bonus`
- `get_boss_status_bonus`

Boss blind naming currently works by changing the live HUD blind name at blind start. It does not replace normal challenge-menu blind definitions.

### Safe update checklist

If you change boss blind names or trainer boss effects:

- update `functions/trainer_battles.lua`
- update the relevant `challenge_*.lua -> boss_sequence`
- update challenge `loc_txt` if the framing changes
- update `functions/boss_hooks.lua` only if generic blind-start status pressure changes too

## 19. Card Spreading, Transformation, and Creation

Primary file:

- `functions/card_creation.lua`

Key functions:

- `apply_element_to_card`
- `create_elemental_playing_card`
- `create_flower_card`
- `transform_random_card_to_element`
- `add_elemental_card_to_deck`
- `add_elemental_card_to_hand`
- `add_elemental_card_to_discard`

This is the system behind phrases like:

- pressure spreads
- boss transformed a card
- trainer added more of an element

### Safe update checklist

If you change spreading behavior:

- update `functions/card_creation.lua`
- update `functions/trainer_battles.lua` if a trainer boss uses it
- update `functions/battle_mode.lua` if battle mode uses it
- update `balance/elemental_pokemon_overrides.lua` if any override uses it
- update `config.lua -> card_creation`

## 20. Pokemon Overrides

Primary files:

- `functions/pokemon_overrides.lua`
- `balance/elemental_pokemon_overrides.lua`
- `backups/override_manifest.lua`

What lives where:

- `pokemon_overrides.lua`
  - runtime wrapper framework
  - counters
  - pending bonus queue
  - hook bridge between damage/status pipeline and per-Pokemon behavior
- `balance/elemental_pokemon_overrides.lua`
  - actual per-Pokemon definitions and balance numbers
- `backups/override_manifest.lua`
  - documentation of which Pokemon are intentionally overridden

### Safe update checklist

If you change one Pokemon's custom behavior:

- update `balance/elemental_pokemon_overrides.lua`
- update `config.lua -> overrides.pokemon`
- update `localization/en-us.lua` only if the player-facing summary text changes
- update `functions/ui_status.lua` only if new counters or summary display rules are needed
- update `functions/constants.lua -> tracked_counters` if you add a new persistent counter

## 21. Counters

Counters include things like:

- Blaze
- Static
- Growth
- Rage
- Splash
- Armor

Primary files:

- `functions/constants.lua -> tracked_counters`
- `functions/pokemon_overrides.lua`
- `functions/ui_status.lua`
- `localization/en-us.lua`

### Safe update checklist

If you add or rename a counter:

- update `functions/constants.lua`
- update `functions/pokemon_overrides.lua`
- update `functions/ui_status.lua`
- update `localization/en-us.lua`

## 22. Debugging and Crash Tracing

Primary files:

- `functions/debug.lua`
- `functions/run_hooks.lua`

Key API:

- `ElementalEditions.debug.log`
- `ElementalEditions.debug.warn`
- `ElementalEditions.debug.error`
- `ElementalEditions.debug.trace`
- `ElementalEditions.debug.wrap`
- `ElementalEditions.debug.safe_call`
- `ElementalEditions.get_debug_trace_id`

What to use when adding or changing a mechanic:

- `debug.log(...)` for normal milestone logs
- `debug.trace(...)` for verbose phase details
- `debug.safe_call(...)` around risky runtime or UI operations
- pass `context` whenever possible so the logger can include ante, hand, phase, and trace ID

Where logs go:

- `print`
- `sendDebugMessage` when available
- `ElementalEditions_debug.log`

Config:

- `config.lua -> debug`

## 23. Compatibility and Legacy Data Repair

Primary files:

- `functions/runtime_compat.lua`
- `main.lua`

What they do:

- normalize custom edition input for old `set_edition({ key = true })` style calls
- repair legacy elemental edition states on cards
- recover optional Pokermon card areas such as `scry_view`

Key functions:

- `recover_optional_cardareas`
- `repair_legacy_card_edition`
- `repair_playing_card_editions`
- `get_edition_center_key`
- `card_has_edition`

### Safe update checklist

If you rename edition IDs or change challenge deck preview encoding:

- update `main.lua`
- update `functions/runtime_compat.lua`
- update any edition definitions
- verify `functions/challenge_framework.lua`

## 24. If You Want To Change X, Start Here

### "I want to change Grass pressure."

Start with:

- `functions/constants.lua`
- `functions/pokermon_bridge.lua`
- `functions/element_channels.lua`
- `functions/card_creation.lua`
- `functions/pressure_damage.lua`

Then update:

- `config.lua -> effectiveness.grass`, `messages.flavor.grass`
- `localization/en-us.lua`
- Grass-heavy challenge text like Erika

### "I want to change how elemental cards damage Pokemon."

Start with:

- `functions/pressure_damage.lua`
- `functions/pokemon_hp.lua`

Then update:

- `config.lua -> damage`
- `functions/feedback.lua`
- `README.md`

### "I want to change what a status does."

Start with:

- `functions/joker_status.lua`

Then update:

- `config.lua -> status`
- `functions/pokemon_overrides.lua`
- `functions/ui_status.lua`
- `localization/en-us.lua`

### "I want to change trainer starting decks."

Start with:

- `challenges/challenge_*.lua`

Then verify:

- `functions/challenge_framework.lua`
- `functions/trainer_battles.lua`
- challenge `loc_txt`

### "I want to change boss Pokemon names."

Start with:

- `functions/trainer_battles.lua`
- each challenge file's `boss_sequence`

### "I want to change how pressure spreads."

Start with:

- `functions/card_creation.lua`
- `functions/trainer_battles.lua`

Then check:

- `functions/battle_mode.lua`
- `balance/elemental_pokemon_overrides.lua`
- `config.lua -> card_creation`, `config.lua -> boss`

### "I want to add a new per-Pokemon elemental mechanic."

Start with:

- `balance/elemental_pokemon_overrides.lua`

Then check:

- `functions/pokemon_overrides.lua`
- `functions/ui_status.lua`
- `localization/en-us.lua`
- `functions/constants.lua` if you need a new counter

## 25. Final Warning

The most common unsafe changes in this mod are:

- changing logic without changing player-facing text
- changing a status without updating its visual mapping
- changing an edition key without updating compatibility helpers
- changing a trainer deck distribution without updating the challenge description
- adding a new counter without adding localization and tooltip support
- changing damage or pressure semantics without updating debug coverage

When in doubt, update the mechanic in four places:

- logic
- config
- localization / tooltip
- debug visibility
