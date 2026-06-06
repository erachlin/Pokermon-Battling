## Backup Policy

Elemental Editions prefers runtime wrappers and does not directly modify `third_party/Pokermon` in the normal workflow.

### Current state
- Direct Pokermon edits made by this pass: none
- Runtime override source: `functions/pokemon_overrides.lua`
- Override definitions: `balance/elemental_pokemon_overrides.lua`
- Override manifest: `backups/override_manifest.lua`

### If direct Pokermon edits ever become necessary
1. Copy the original file into `backups/pokermon_originals/<relative_path>.bak`
2. Record the original path, timestamp, reason, and checksums in `backups/override_manifest.lua`
3. Keep the runtime override version enabled by default when possible

### Restore strategy
- Current restore path is simply disabling the runtime overrides in `config.lua`
- No restore script is required while the system remains runtime-only
