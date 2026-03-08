# Euro Truck Simulator 2 or American Truck Simulator Dedicated Server Scripts

Bash scripts for installing and updating **ATS** and **ETS2** dedicated servers on **Ubuntu Server 22.04**.

## Scripts

- `install-server.sh` — install a new dedicated server
- `update-server.sh` — update an existing dedicated server

## Supported games

- American Truck Simulator (ATS)
- Euro Truck Simulator 2 (ETS2)

## Requirements

- Ubuntu Server 22.04
- server_packages.sii (This file must come from a normal game installation)
- server_packages.dat (This file must come from a normal game installation)

## Quick start

Clone the repository:

```bash
git clone https://github.com/VitorThorvi/ets2-ats-ubuntu-server
cd ets2-ats-ubuntu-server
chmod +x install-server.sh update-server.sh
```

Run the installer: `sudo ./install-server.sh`

Update: `sudo ./update-server.sh`

---

## Notes

These scripts install and update the dedicated server files using SteamCMD.

**To fully run an ATS or ETS2 dedicated server**, you must also export and provide:
	•	server_packages.sii
	•	server_packages.dat

These files must come from a normal game installation.
