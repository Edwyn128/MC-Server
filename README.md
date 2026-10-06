# MC-Server

Currently hosting a self-hosted **Project Zomboid** dedicated server on
Windows. The repo previously hosted a Minecraft Bedrock Edition server; that
setup is still here and working (see **Previous setup: Minecraft Bedrock**
below) in case you want to switch back later.

## Project Zomboid - quick start

```powershell
# 1. Download SteamCMD (if needed) and install/update the PZ Dedicated Server into .\server-pz
.\scripts\pz-setup.ps1

# 2. Deploy the server config (pzserver.ini + pzserver_SandboxVars.lua) to
#    %USERPROFILE%\Zomboid\Server\ - pick a real RCON password here, it's
#    never committed to the repo
.\scripts\pz-deploy-config.ps1 -RconPassword "<a real strong password>"

# 3. Open the required ports in Windows Firewall (once, as Administrator)
.\scripts\pz-open-firewall.ps1

# 4. Start the server
.\scripts\pz-start.ps1
```

### Repo layout (Project Zomboid)

| Path | Purpose |
|---|---|
| `scripts/pz-setup.ps1` | Downloads SteamCMD + installs/updates the PZ Dedicated Server into `server-pz/` (safe to re-run to update) |
| `scripts/pz-deploy-config.ps1` | Copies `config/pz/pzserver.ini` + `pzserver_SandboxVars.lua` into `%USERPROFILE%\Zomboid\Server\` (where PZ actually reads them from - not the install dir), injecting a real RCON password into your local copy only |
| `scripts/pz-open-firewall.ps1` | Opens inbound UDP 27075/27076 (the ports set in `pzserver.ini`) in Windows Firewall |
| `scripts/pz-start.ps1` | Launches `server-pz\StartServer64.bat -servername pzserver` |
| `config/pz/pzserver.ini` | Server settings (PVP, max players, ports, RCON port, etc.) - `RCONPassword` is a placeholder here on purpose, since this repo is public |
| `config/pz/pzserver_SandboxVars.lua` | World/gameplay sandbox settings (zombie population, loot, loot respawn, etc.) |
| `server-pz/` | *Not committed* - the actual game server, created by `pz-setup.ps1` |

### Config file note

Your friend sent two files whose names and contents didn't match up - the
one named "pzserver ini.txt" actually contained the Lua `SandboxVars` table,
and "sandbox.txt" actually contained the real `.ini` settings. This repo's
`config/pz/` files are named and matched by their *actual content*, so they
load correctly regardless of what the originals were called.

### Networking

Same situation as before if your ISP has you behind CGNAT (see
[NETWORKING.md](NETWORKING.md) for how we diagnosed that previously) - you'll
likely need a playit.gg tunnel again, this time for UDP 27075 and 27076
instead of Minecraft's ports. Say the word if you want that set up for PZ.

### Updating

Re-run `.\scripts\pz-setup.ps1` any time to update the server - SteamCMD only
downloads what changed, and nothing under `%USERPROFILE%\Zomboid\` (your
saves/config) is touched by it.

---

## Previous setup: Minecraft Bedrock

A self-hosted Minecraft **Bedrock Edition** dedicated server, with official
Add-Ons (Bedrock's version of mods) and public internet access for
console/mobile/PC friends. Cross-play works by default across Xbox,
PlayStation, Switch, mobile, and Windows when everyone connects to the same
Bedrock Dedicated Server (BDS).

### Quick start

```powershell
.\scripts\setup.ps1          # downloads/installs BDS into .\server
.\scripts\open-firewall.ps1  # once, as Administrator
.\scripts\start.ps1
```

Edit `server\server.properties` (name, gamemode, max-players, etc.) and
re-run `start.ps1` to pick up changes - see `config\server.properties.template`
for the values this repo starts you with.

### Repo layout (Minecraft Bedrock)

| Path | Purpose |
|---|---|
| `scripts/setup.ps1` | Downloads/installs BDS into `server/`, preserves your world+config on re-run (use it to update versions too) |
| `scripts/start.ps1` | Launches `server/bedrock_server.exe` |
| `scripts/open-firewall.ps1` | Opens inbound UDP 19132/19133 in Windows Firewall |
| `scripts/import-world.ps1` | Imports a `.mcworld` file (e.g. exported from a Realm) and points the server at it |
| `scripts/reset-world.ps1` | Moves the current world aside (backup, not deleted) so the server generates a fresh one |
| `scripts/deactivate-pack.ps1` | Removes one pack (by UUID) from the world's activation files without deleting its files |
| `scripts/install-addons.ps1` | Scans a folder (default: Downloads) for `.mcpack`/`.mcaddon` files and installs+activates everything found in one pass |
| `scripts/activate-pack.ps1` | Install *and* activate a single already-unzipped behavior/resource pack for your world |
| `scripts/install-pack.ps1` | Just copies a pack into the server, without activating it (used internally / for manual control) |
| `config/server.properties.template` | Starting server config, seeded on first setup only |
| `addons/` | Add-on (mod) packs, with a minimal example pack and install instructions |
| `server/` | *Not committed* - created by setup.ps1 (binaries + your world) |

### Adding mods (Add-Ons)

See **[addons/README.md](addons/README.md)**. Short version: unzip a
`.mcpack`/`.mcaddon`, then run:
```powershell
.\scripts\activate-pack.ps1 -PackPath <folder> -Type behavior
```
It copies the pack in and activates it for your world in one step.

### Updating

Re-run `.\scripts\setup.ps1` any time - it downloads the current BDS release
and merges it in without touching your existing world, `server.properties`,
allowlist, or installed packs.

### Notes / open items

- `scripts/setup.ps1` resolves the download link via an undocumented Mojang
  API that community server-hosting tools rely on; if Mojang changes it, the
  script tells you how to pass a manually-copied link instead
  (`-ManualDownloadUrl`). Worth a quick check the first time you run it.
- Running as a background Windows service (so it survives logout/reboot
  without a terminal open) isn't set up yet - say the word and I'll add an
  NSSM-based service script.
- Automated world backups aren't set up yet either - straightforward to add
  (zip `server/worlds/` on a schedule) if you want it.
