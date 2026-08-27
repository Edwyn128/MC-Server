# Add-Ons (Bedrock's version of "mods")

Bedrock Edition doesn't have Forge/Fabric-style mods. It has **Add-Ons**: Behavior
Packs (server-side logic - custom recipes, loot, spawn rules, functions, and
scripted behavior) and Resource Packs (client-side - textures, models, sounds).
Because they're official Mojang formats, every player connects fine regardless
of platform (console, mobile, PC) - that's what keeps cross-play working.

This repo includes one example, `example_starter_kit/`, so you can see the
shape of a pack before writing your own or dropping in one you downloaded.

## Installing a pack onto the server

1. Copy the pack folder into `server/behavior_packs/<pack name>/` (or
   `server/resource_packs/` for a resource pack). `scripts/install-pack.ps1`
   does this copy for you - see below.
2. Activate it for your world by adding its `uuid` and `version` (from the
   pack's `manifest.json`) to:
   - `server/worlds/<Bedrock level>/world_behavior_packs.json`
   - `server/worlds/<Bedrock level>/world_resource_packs.json`

   Example entry:
   ```json
   [
     { "pack_id": "7a020c17-f48d-4d6c-8d94-a1191755742f", "version": [1, 0, 0] }
   ]
   ```
3. Restart the server (`scripts/start.ps1`).

## Using the example pack

```powershell
.\scripts\install-pack.ps1 -PackPath .\addons\example_starter_kit -Type behavior
```

Then add its UUID/version to `world_behavior_packs.json` as shown above,
restart the server, and any op can run `/function starterkit` in-game.

## Where to find more add-ons

Only install packs from sources you trust - a behavior pack can run arbitrary
server-side logic. The Minecraft Marketplace (in-game) and community sites
that publish `.mcpack`/`.mcaddon` files (which are just renamed `.zip`) are
the common sources. Unzip a `.mcpack`/`.mcaddon` before copying it in with
`install-pack.ps1`.

## Going further: the Scripting API

For real mod-like behavior (custom game logic in JavaScript/TypeScript), Bedrock
has an official Scripting API (`@minecraft/server`). It requires enabling
experimental toggles in the world and is a bigger lift than a data-only pack -
ask if you want a starter project scaffolded for it once the base server is
running.
