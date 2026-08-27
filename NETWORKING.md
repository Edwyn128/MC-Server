# Making the server reachable from outside your home network

Bedrock uses **UDP** (not TCP) on port **19132** (IPv4) and **19133** (IPv6) by
default - matching `server-port`/`server-portv6` in `server.properties`.

## 1. Windows Firewall (this machine)

```powershell
# Run once, as Administrator
.\scripts\open-firewall.ps1
```

## 2. Port forwarding (your router)

This step happens on your router's admin page, not from this computer, so I
can't do it for you - steps vary by router brand. In general:

1. Find this PC's local IP: `ipconfig` -> "IPv4 Address" (e.g. `192.168.1.42`).
   Set it to a static/reserved IP in your router (DHCP reservation) so it
   doesn't change and break the forward later.
2. Log into your router's admin page (commonly `192.168.1.1` or `192.168.0.1`).
3. Find "Port Forwarding" / "Virtual Server" / "NAT".
4. Forward external UDP 19132 -> internal `<this PC's IP>`:19132 (and 19133 if
   you want IPv6 players too).
5. Save/apply - some routers reboot the network briefly.

## 3. Find/track your public IP

Friends connect using your home's public IP, which residential ISPs usually
change periodically. Two options:

- Check it manually when needed (search "what is my IP" from this PC, or
  `(Invoke-WebRequest ifconfig.me/ip).Content` in PowerShell) and share it
  with friends when it changes.
- Use a free Dynamic DNS service (e.g. DuckDNS, No-IP) that gives you a
  stable hostname (like `yourserver.duckdns.org`) and runs a small updater
  client on this PC to keep it pointed at your current IP. Recommended if
  you'll be running this long-term - say the word and I'll wire up a DDNS
  updater script once you've picked a provider and created an account
  (that account creation has to be you, I can't sign up for a third-party
  service on your behalf).

## 4. Connecting

- **Windows/PC**: Friends on Bedrock for Windows add a server via
  Friends tab -> Servers -> Add Server, using your IP/hostname and port 19132.
- **Console/mobile**: Same "Add Server" flow under the Friends/Servers tab in
  the game.

## Security notes

- Anyone with your IP/hostname and port can attempt to join while
  `online-mode=true` requires an Xbox Live sign-in, which blocks anonymous
  connections - keep that setting on for a public server.
- Consider `allow-list=true` plus `server/allowlist.json` if you want to
  restrict to named accounts instead of open public join.
- Exposing a game server to the internet does carry the usual risk of a
  determined attacker probing your home network; a dedicated router-level
  firewall and keeping BDS updated (`scripts/setup.ps1` re-run) are the main
  mitigations.
