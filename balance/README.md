## Balance Notes

Elemental Editions now treats elemental cards as battlefield pressure first and score fuel second.

### Main tuning points
- `config.lua -> damage.scored_damage_base`
- `config.lua -> damage.discard_damage_base`
- `config.lua -> damage.debug_aoe_damage`
- `config.lua -> damage.same_type_resist`
- `config.lua -> damage.lightning_ground_multiplier`
- `config.lua -> damage.earth_bird_multiplier`
- `config.lua -> effectiveness`
- `config.lua -> status`
- `config.lua -> messages`
- `config.lua -> performance`
- `config.lua -> boss`
- `config.lua -> card_creation`
- `config.lua -> overrides.pokemon`

### Current combat shape
- Scored elemental cards deal AoE damage to all eligible Pokemon Jokers.
- Discarded elemental cards deal smaller AoE damage and lower status pressure.
- Trainer boss themes can add damage and status bonuses to their own element while spreading more cards of that type through the deck.
- Knocked-out Pokemon do not take further elemental damage in the current pass.
- Flower Cards remain the Grass pressure channel.

### Override tuning
- Runtime Pokemon overrides live in `balance/elemental_pokemon_overrides.lua`.
- Global enable: `config.lua -> gameplay.enable_pokemon_overrides`
- Per-Pokemon toggles: `config.lua -> overrides.pokemon`
- Override debug: `config.lua -> overrides.debug_logging`
- In-game override text is appended through `functions/ui_status.lua` and `functions/pokemon_overrides.lua`.
- New expansion batch in this pass: Eevee, Vaporeon, Flareon, Butterfree, Sandslash, Vileplume, Bellossom, Growlithe, Arcanine, and Dragonite.

### Performance tuning
- Keep `config.lua -> debug.enabled = false` for normal play.
- Use `config.lua -> messages.aggregate_aoe_damage_messages` and `messages.max_messages_per_scoring_event` to reduce popup overhead.
- Use `config.lua -> performance.logging_enabled` and `performance.log_threshold_ms` to time only the slowest paths.
- `functions/element_channels.lua` now caches scored and held element summaries per event; if you add new scans, prefer those helpers over rescanning hands yourself.

### Revert path
- No direct Pokermon source edits are used in this pass.
- Disable all runtime redesigns by setting:
  - `gameplay.enable_pokemon_overrides = false`
- Disable the broader battle pressure layer by setting:
  - `gameplay.enable_elemental_damage = false`
  - `gameplay.enable_discard_damage = false`
  - `gameplay.enable_joker_statuses = false`

### Known hot spots
- Water and Grass AoE can snowball sustain quickly in starter-heavy teams.
- Lightning into Bird-typed override targets is intentionally dangerous.
- Earth and Metal-adjacent overrides can stack a lot of mitigation if armor values are overtuned.
- Trainer challenge boss bonuses can spike faster than normal runs if both AoE pressure and card spread are overtuned.
- Mixed-element scalers like Eevee and Dragonite can snowball if card creation limits are raised too high.
