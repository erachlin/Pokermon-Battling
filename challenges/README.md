# Trainer Challenges

Elemental Editions trainer challenges are data-driven challenge files under `challenges/`.

## Current Set

- `Youngster's First Battle`
- `Brock's Rock Wall`
- `Misty's Tidal Trial`
- `Lt. Surge's Voltage Test`
- `Erika's Bloom Garden`

## How They Work

- Each challenge registers a trainer definition through `functions/trainer_battles.lua`.
- The trainer definition controls:
  - starter elemental distribution
  - ante growth distribution
  - boss Pokemon sequence
  - boss element pressure and intro text
- Challenge files themselves stay thin:
  - starting Jokers
  - optional starting consumables
  - deck type
  - button colors
  - challenge text

## Tuning

- Global toggle: `config.lua -> gameplay.enable_trainer_challenges`
- Per-challenge toggles: `config.lua -> trainer_challenges`
- Boss pressure tuning: `config.lua -> boss`
- Shared battle seeding: `functions/battle_mode.lua`

## Naming

Trainer bosses use a safe runtime blind-name approximation:

- At blind start, the active trainer boss name is pushed into the live blind HUD.
- This avoids invasive global blind hacks while still making the run feel like a trainer battle.
