# Add-Ons (Bedrock's version of "mods")

Bedrock Edition doesn't have Forge/Fabric-style mods. It has **Add-Ons**: Behavior
Packs (server-side logic - custom recipes, loot, spawn rules, functions, and
scripted behavior) and Resource Packs (client-side - textures, models, sounds).
Because they're official Mojang formats, every player connects fine regardless
of platform (console, mobile, PC) - that's what keeps cross-play working.

This repo includes one example, `example_starter_kit/`, so you can see the
shape of a pack before writing your own or dropping in one you downloaded.

## Installing a pack onto the server (one command)

```powershell
.\scripts\activate-pack.ps1 -PackPath <path to unzipped pack folder> -Type behavior
```

(use `-Type resource` for a resource pack). This copies the pack into
`server/behavior_packs/` or `server/resource_packs/` **and** edits your
world's `world_behavior_packs.json`/`world_resource_packs.json` for you - no
manual JSON editing. It auto-detects your world folder if there's only one
under `server/worlds/`; pass `-WorldName` if you have more than one.

Restart the server (`scripts/start.ps1`) afterward for the pack to take effect.

Under the hood this does the same two things listed for reference below, in
case you ever want to do it by hand or debug why a pack isn't loading:
1. Copy the pack folder into `server/behavior_packs/<pack name>/` (or
   `server/resource_packs/`).
2. Add its `uuid`/`version` (from `manifest.json`) to
   `server/worlds/<Bedrock level>/world_behavior_packs.json` (or
   `world_resource_packs.json`), e.g.
   ```json
   [
     { "pack_id": "7a020c17-f48d-4d6c-8d94-a1191755742f", "version": [1, 0, 0] }
   ]
   ```

## Using the example pack

```powershell
.\scripts\activate-pack.ps1 -PackPath .\addons\example_starter_kit -Type behavior
```

Restart the server, and any op can run `/function starterkit` in-game.

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
