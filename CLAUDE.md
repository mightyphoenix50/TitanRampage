# Titan Rampage — Claude Code guide

Multiplayer Roblox kaiju destruction game. Place ID `131002954769216`. Player-facing design doc: `INSTRUCTIONS.md`. World/asset specs and roadmap: `HANDOFF.md`. Per-milestone log: `CHANGELOG.md` (append an entry for every milestone, same format).

## Two sources of truth

- **Code** lives in `src/` and syncs to Studio through Rojo (`default.project.json`, Rojo 7.7.1 pinned in `rokit.toml`). Edit code here, never in Studio.
- **World geometry and assets** live only in the Studio place file, not in git: `Workspace.KaijuHub`, the city maps, `ReplicatedStorage.Assets` (titan models, audio), and `ReplicatedStorage.Remotes` (the RemoteEvent/RemoteFunction instances). Change these through the `Roblox_Studio` MCP (`execute_luau`, `inspect_instance`, `search_game_tree`). `HubService` preserves manual Studio edits under `Workspace.KaijuHub` on server start.
- `scratch/` (gitignored) holds one-off Luau build scripts run through the Studio MCP.

## Layout

| Path | Maps to | Notes |
| --- | --- | --- |
| `src/server/ServerBootstrap.server.luau` | ServerScriptService | Requires every service, calls all `Init()` then all `Start()` in a fixed order |
| `src/server/Services/*.luau` | ServerScriptService.Services | One ModuleScript per service, `Init`/`Start` lifecycle |
| `src/shared/Config/*.luau` | ReplicatedStorage.Config | Pure data tables (titans, cities, upgrades, monetization, audio) |
| `src/shared/Shared/*.luau` | ReplicatedStorage.Shared | Code used by both sides (animation, audio, titan registry) |
| `src/client/Controllers/*.client.luau` | StarterPlayerScripts | Input, camera, lighting |
| `src/client/UI/*.client.luau` | StarterGui.MainUI | HUDs built in code |

New service: add the module under `Services/` and register it in the `services` list in `ServerBootstrap`, respecting dependency order (PlayerDataService first).

## Conventions

- Every file starts with `--!strict`. Keep it that way.
- Services are plain module tables (`local X = {} ... return X`); no `_G`/`shared`.
- Log with the `[ServiceName]` prefix used throughout.
- 4-space indentation, double quotes (see `stylua.toml`).

## Non-negotiable rules

- **Server authority.** Every `OnServerEvent`/`OnServerInvoke` handler type-checks its arguments and validates against server state (cooldowns, ownership, cash, distance). Clients only ask; the server decides damage, cash, XP and unlocks.
- **Monetization.** Free/sandbox grants (`MonetizationService.HandleSandboxBuy`) must stay gated behind `RunService:IsStudio()`. Every real `AssetId` in `MonetizationConfig` is `0` until the passes/products are created on the Creator Dashboard; fill them in before publishing.
- **Player data.** Never save over stored data when a load failed (`isLoadFailed` lock in `PlayerDataService`). Bump `CURRENT_SCHEMA_VERSION` and add a migration step for any profile shape change.

## Verifying changes

1. `rojo build -o "$TEMP/check.rbxlx"` — catches project/tree errors.
2. With `rojo serve` connected in Studio, use the Studio MCP: `start_stop_play` to playtest, `get_console_output` to read errors, `screen_capture` to look.
3. `selene src` must report 0 errors (style-only lints are relaxed in `selene.toml`). `stylua --check src` must pass; run `stylua src` before committing. CI (`.github/workflows/ci.yml`) runs `rojo build`, `selene --allow-warnings src` and `stylua --check src` on every push to main and on every PR.

Tools (rojo, selene, StyLua, luau-lsp) are pinned in `rokit.toml` and resolved by Rokit shims in `~/.rokit/bin`. Run them from the repo root: a shim run outside a directory with `rokit.toml` fails with "Failed to find tool".

For a Luau review use the `roblox-dev:roblox-reviewer` agent or `/roblox-dev:review`.
