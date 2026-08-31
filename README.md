# MC-Server

A self-hosted Minecraft **Bedrock Edition** dedicated server, set up for
Windows, with official Add-Ons (Bedrock's version of mods) and public
internet access for console/mobile/PC friends.

Bedrock is cross-play by default across Xbox, PlayStation, Switch, mobile,
and Windows when everyone connects to the same Bedrock Dedicated Server (BDS)
- there's nothing extra to bridge platforms together.

## Quick start

```powershell
# 1. Download and install the latest BDS into .\server (also accepts the
#    Minecraft EULA/Privacy Policy on your behalf - see scripts\setup.ps1)
.\scripts\setup.ps1

# 2. Open the required port in Windows Firewall (once, as Administrator)
.\scripts\open-firewall.ps1

# 3. Start the server
.\scripts\start.ps1
```

Then edit `server\server.properties` (name, gamemode, max-players, etc.) and
re-run `start.ps1` to pick up changes - see `config\server.properties.template`
for the values this repo starts you with.

## Repo layout

| Path | Purpose |
|---|---|
| `scripts/setup.ps1` | Downloads/installs BDS into `server/`, preserves your world+config on re-run (use it to update versions too) |
| `scripts/start.ps1` | Launches `server/bedrock_server.exe` |
| `scripts/open-firewall.ps1` | Opens inbound UDP 19132/19133 in Windows Firewall |
| `scripts/import-world.ps1` | Imports a `.mcworld` file (e.g. exported from a Realm) and points the server at it |
| `scripts/reset-world.ps1` | Moves the current world aside (backup, not deleted) so the server generates a fresh one |
| `scripts/install-addons.ps1` | Scans a folder (default: Downloads) for `.mcpack`/`.mcaddon` files and installs+activates everything found in one pass |
| `scripts/activate-pack.ps1` | Install *and* activate a single already-unzipped behavior/resource pack for your world |
| `scripts/install-pack.ps1` | Just copies a pack into the server, without activating it (used internally / for manual control) |
| `config/server.properties.template` | Starting server config, seeded on first setup only |
| `addons/` | Add-on (mod) packs, with a minimal example pack and install instructions |
| `NETWORKING.md` | Port forwarding, dynamic DNS, and connection instructions for public play |
| `server/` | *Not committed* - created by setup.ps1 (binaries + your world) |

## Playing over the internet

You said you want console and mobile friends to connect from outside your
home network - see **[NETWORKING.md](NETWORKING.md)** for port forwarding and
optional dynamic DNS. That part happens on your router, not from this repo.

## Adding mods (Add-Ons)

See **[addons/README.md](addons/README.md)**. Short version: unzip a
`.mcpack`/`.mcaddon`, then run:
```powershell
.\scripts\activate-pack.ps1 -PackPath <folder> -Type behavior
```
It copies the pack in and activates it for your world in one step.

## Updating the server version

Re-run `.\scripts\setup.ps1` any time - it downloads the current BDS release
and merges it in without touching your existing world, `server.properties`,
allowlist, or installed packs.

## Notes / open items

- `scripts/setup.ps1` resolves the download link via an undocumented Mojang
  API that community server-hosting tools rely on; if Mojang changes it, the
  script tells you how to pass a manually-copied link instead
  (`-ManualDownloadUrl`). Worth a quick check the first time you run it.
- Running as a background Windows service (so it survives logout/reboot
  without a terminal open) isn't set up yet - say the word and I'll add an
  NSSM-based service script.
- Automated world backups aren't set up yet either - straightforward to add
  (zip `server/worlds/` on a schedule) if you want it.
