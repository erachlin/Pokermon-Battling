# Pokemon Overrides

Elemental Editions does not direct-edit Pokermon source files for its redesign layer. Runtime overrides are registered from:

- `functions/pokemon_overrides.lua`
- `balance/elemental_pokemon_overrides.lua`

## How Overrides Work

- Pokermon Joker centers are located after Pokermon loads.
- Their original `calculate` functions are preserved on the center as `_elemental_original_calculate`.
- Elemental Editions appends extra behavior rather than replacing the Joker definition files in `third_party/Pokermon`.
- Override-specific tooltip text is exposed in-game through `functions/ui_status.lua`.

## Main Helper Hooks

Most overrides should stay inside these helpers instead of inventing ad-hoc paths:

- `modify_incoming_damage`
- `on_damage_taken`
- `on_damage_prevented`
- `on_element_card_scored`
- `on_element_card_discarded`
- `on_status_applied`
- `on_status_cleared`
- `calculate_bonus`

Shared utility helpers are available through `ElementalEditions`, especially:

- `get_scored_element_count(context, element_key)`
- `get_held_element_count(context, element_key)`
- `get_elemental_counter(card, counter_key)`
- `add_elemental_counter(card, counter_key, amount)`
- `spend_elemental_counter(card, counter_key, amount)`
- `queue_pending_bonus(card, field, amount)`
- `heal_pokemon(card, amount, context)`
- `clear_joker_status(card, status_key, reason)`
- `transform_random_card_to_element(element_key, filter, args)`

## Current Override Roster

Starters and evolutions:

- Bulbasaur
- Ivysaur
- Venusaur
- Charmander
- Charmeleon
- Charizard
- Squirtle
- Wartortle
- Blastoise
- Pikachu
- Raichu

Earth / Rock / Steel:

- Geodude
- Onix
- Steelix
- Sandshrew
- Sandslash

Water / Electric / iconics:

- Gyarados
- Jolteon
- Zapdos
- Magikarp
- Voltorb
- Electrode
- Staryu
- Starmie
- Psyduck
- Golduck
- Vaporeon

Grass / status / support:

- Oddish
- Caterpie
- Butterfree
- Vileplume
- Bellossom

Fire and flexible:

- Growlithe
- Arcanine
- Eevee
- Flareon
- Dragonite
- Snorlax
- Pidgey

## Tuning

- Global master switch: `config.lua -> gameplay.enable_pokemon_overrides`
- Per-Pokemon toggles: `config.lua -> overrides.pokemon`
- Override debug chatter: `config.lua -> overrides.debug_logging`
- Card-creation safety limits: `config.lua -> card_creation`

## Safety Notes

- Keep overrides idempotent and readable.
- Prefer counters, healing, prevention, and queued score bonuses over risky direct mutation during scoring.
- If an override creates or transforms cards, use the shared helpers so per-hand and per-blind limits still apply.
- Do not edit `third_party/Pokermon` unless the runtime framework truly cannot support the change.
