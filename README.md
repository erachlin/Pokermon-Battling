# Elemental Editions

`Elemental Editions` is a standalone SMODS add-on for `Pokermon`. It does not modify the Balatro install tree or vendor Pokermon into this repo. The repo root is the mod root.

## What It Does

The current mechanics pass builds on the HP/status foundation and turns elemental cards into a clearer battle system:

- Fire, Water, Earth, and Lightning exist as custom editions using the mod-local shader assets.
- Flower cards from Pokermon are reused as the Grass pressure channel.
- Pokemon Jokers gain persistent HP.
- Scored elemental cards deal AoE damage to all eligible Pokemon Jokers.
- Discarded elemental cards deal smaller AoE damage and lower status pressure.
- Type effectiveness now materially changes incoming damage.
- Elemental pressure can apply temporary Joker statuses:
  - Burned
  - Paralyzed
  - Dazed
  - Confused
  - Asleep
- Status conditions now carry both downsides and upsides.
- Status conditions can temporarily repaint Pokemon Jokers with elemental status visuals.
- Knocked-out Pokemon Jokers are debuffed through a centralized mod hook instead of being deleted.
- KO'd Pokemon auto-revive at end of blind by default.
- Fire pressure can add the separate `Singed` card state, which remains distinct from the `Burned` Joker status.
- Selected Pokermon Jokers now have runtime elemental redesigns without modifying Pokermon source files.
- Pokemon override tooltips now append in-game `Elemental:` guidance so players can see each redesign's role and hooks.
- Card-based elemental pressure now uses an explicit all-target AoE pipeline for scored, discarded, and held pressure.
- Trainer challenge runs can layer themed boss pressure and element spreading on top of that shared AoE system.

Existing Pokermon Joker abilities remain the primary scoring engine. The elemental move-to-score conversion layer is intentionally deferred.

## New Entry Points

- Trainer challenges:
  - `Youngster's First Battle`
  - `Brock's Rock Wall`
  - `Misty's Tidal Trial`
  - `Lt. Surge's Voltage Test`
  - `Erika's Bloom Garden`
  - Each activates trainer battle mode, starts with a themed elemental spread already baked into the challenge deck preview, and applies ante-scaled boss-Pokemon pressure.
- `Elemental Battle Deck`:
  - Activates the same battle mode in normal runs.
  - Starts with Bulbasaur and a Pokeball.
  - Seeds one Fire, Water, Earth, and Lightning card into the deck and grows by Ante.

## Repo Layout

```text
pokermon-elemental-editions/
  elemental_editions.json
  main.lua
  config.lua
  README.md
  assets/
    shaders/
  balance/
  backups/
  editions/
  enhancements/
  functions/
  localization/
  tools/
```

## GitHub Setup

`gh` is not required by this repo. Create the remote repository through the GitHub web UI, then connect this local repo:

```powershell
git remote add origin git@github.com:<you>/pokermon-elemental-editions.git
git branch -M main
git push -u origin main
```

## Install

Use the install helper to stage this mod into `%APPDATA%\Balatro\Mods`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\install.ps1
```

To also stage an external Pokermon checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\install.ps1 -PokermonSource "C:\path\to\Pokermon"
```

The script symlinks by default and falls back to copy mode when needed.

## Config Notes

Key config groups live in `config.lua`:

- `gameplay`: enable or disable HP, scored/discard damage, statuses, status visuals, boss attacks, starter infusion, held-card pressure, auto-revive, and runtime overrides.
- `debug`: central debug toggles, log destinations, and per-category tracing controls.
- `messages`: aggregate damage popup behavior, per-target popup threshold, per-scoring-event message caps, elemental flavor text, and message duration multipliers.
- `performance`: optional timing logs for heavy paths, with a configurable millisecond threshold.
- `battle_mode`: controls the special challenge/deck elemental seeding pace and starter loadout.
- `trainer_challenges`: global and per-trainer challenge toggles.
- `boss`: trainer boss damage/status bonuses and how often they spread more elemental cards.
- `card_creation`: shared limits for Pokémon or boss effects that transform or create elemental cards.
- `hp`: first-pass HP tiers and auto-revive values.
- `damage`: AoE base damage values, same-type resistance, and special Lightning-vs-Earth / Earth-vs-Bird tuning.
- `effectiveness`: the simplified Pokemon-inspired type chart used by elemental pressure.
- `status`: durations, status chances, passive downsides, and upside counters.
- `overrides`: master and per-Pokemon runtime override toggles.
- `pressure`: conservative edition scoring values.
- `card_status`: `Singed` tuning.

Debug logging is now quiet by default. Set `debug.enabled = true` when you want console, Lovely, or file logs, and set `debug.file_enabled = true` to write `ElementalEditions_debug.log` in the Balatro save directory. Optional timing logs live under `performance.logging_enabled` and `performance.log_threshold_ms`.

## Maintainer Guide

For a system-by-system map of where each gameplay mechanic lives, what other files must be updated with it, and where each mechanic is explained to the player, see:

- `docs/MECHANICS_MAP.md`
- `pokemon_overrides/README.md`

## Current Limitations

- KO is fully enforced through `SMODS.current_mod.set_debuff`.
- Temporary statuses affect existing Pokemon Joker outputs through a centralized `Card:calculate_joker()` wrapper.
- Some override bonuses resolve through centralized Joker calculation or pending-bonus release rather than custom per-Pokemon UI effects.
- Blind renaming for trainer aces is a safe approximation: the active boss Pokemon name is injected into the live blind HUD at blind start rather than replacing challenge-menu blind previews.
- Type-specialist trainer challenge decks now preview only their own elemental starter pressure: Brock starts Earth-only, Misty Water-only, Surge Lightning-only, and Erika Flower-only.
- Challenge deck preview uses a compatibility wrapper so custom elemental editions can appear safely in the deck viewer.
- Pokemon tooltips now explain HP, elemental damage, type effectiveness, active statuses, and override-specific `Elemental:` behavior.
- `Singed` is still edition-backed in this version because the migrated stub already had a working shader path for it. That means it cannot stack on top of another edition on the same playing card.
- Starter support currently infuses four existing deck cards instead of creating four new ones. This keeps the run visible immediately without relying on a more invasive playing-card creation path.
- Trainer deck shaping mostly transforms existing cards into elemental/Flower pressure instead of permanently increasing deck size.
- Pokermon source files are still not edited directly; redesigns live in the runtime override layer under `functions/pokemon_overrides.lua` and `balance/elemental_pokemon_overrides.lua`.

## Manual Test Checklist

- Mod loads after Pokermon.
- Missing Pokermon causes a clean no-op instead of a crash.
- Fire, Water, Earth, and Lightning editions register from `assets/shaders`.
- Flower cards are detected as Grass pressure.
- With 2+ Pokemon Jokers, scoring one elemental card damages every eligible Pokemon Joker.
- With 2+ Pokemon Jokers, multiple elemental cards stack and still damage every eligible Pokemon Joker once per card.
- Discarded elemental cards damage every eligible Pokemon Joker when discard pressure is enabled.
- AoE debug logs can show target counts greater than 1 when `damage.debug_aoe_damage = true`.
- With `debug.enabled = true`, `ElementalEditions_debug.log` should appear in the Balatro save directory and mirror the most important scoring/discard/status traces.
- With `performance.logging_enabled = true`, timing logs should only appear for paths that exceed `performance.log_threshold_ms`.
- Scored elemental cards deal 6 base damage before effectiveness.
- Discarded elemental cards deal 3 base damage before effectiveness.
- Fire vs Grass is super effective.
- Water vs Fire is super effective.
- Fire vs Water is resisted.
- Grass vs Fire is resisted.
- Lightning vs Earth uses the configured reduced multiplier.
- Same-type resistance works.
- `Youngster's First Battle`, `Brock's Rock Wall`, `Misty's Tidal Trial`, `Lt. Surge's Voltage Test`, and `Erika's Bloom Garden` appear in the challenge list.
- Trainer challenge deck viewers show their starter Fire/Water/Earth/Lightning/Flower pressure before the run begins.
- Trainer challenges do not rely on Eternal Jokers by default.
- Each trainer challenge starts with its intended team and themed elemental distribution.
- Boss-Pokemon intros appear at blind start, and boss-themed effects spread matching elemental pressure.
- `Elemental Battle Deck` appears in the deck list and activates battle mode.
- Pokemon Jokers receive HP and keep it across save/load.
- Scored Fire cards damage and can Burn.
- Scored Lightning cards damage and can Paralyze.
- Scored Earth cards damage and can Daze.
- Scored Water cards damage and can Confuse.
- Flower cards can apply Asleep.
- Burned, Paralyzed, Dazed, Confused, and Asleep all provide both a downside and an upside.
- Status visuals restore the Joker's original edition safely after the status clears.
- Damage messages appear for elemental hits without flooding the screen on large AoE turns.
- Card creation effects obey the per-hand and per-blind limits in `config.lua`.
- Override tooltips appear on supported Pokemon Jokers and describe their Elemental Editions hooks.
- Runtime Pokemon overrides can be disabled globally or per Pokemon in `config.lua`.
- KO debuffs the Joker without deleting it.
- KO recovery happens at end of blind when enabled.
- `Singed` stays separate from the `Burned` Joker status.
- Existing Pokermon scoring still works aside from KO/status suppression applied through the centralized wrapper.
