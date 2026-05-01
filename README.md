# Unturned Docker

[![Publish Images](https://github.com/brasscord-network/docker-unturned-server/actions/workflows/publish.yml/badge.svg?branch=master)](https://github.com/brasscord-network/docker-unturned-server/actions/workflows/publish.yml)

Docker-focused Unturned dedicated server images built on top of `cm2network/steamcmd`.

The repository ships two build targets:

- `vanilla`: runtime bootstrap for the official dedicated server.
- `ldm`: the same runtime bootstrap plus `Legally Distinct Missile` pinned to `v4.9.3.18`.

Futures builds after v1.x will use Golang to build.

## Quick Start

### Compose Method:

1. Create a new file called compose.yml
2. You can insert this compose below or use one of the example composes

```yaml
services:
  server:
    image: ghcr.io/brasscord-network/docker-unturned-server:vanilla
    tty: true
    stdin_open: true
    ports:
      - "27015:27015/tcp"
      - "27015:27015/udp"
      - "27016:27016/tcp"
      - "27016:27016/udp"
    volumes:
      - data:/home/steam/Unturned

volumes:
  data:
```

3. Once you have this compose setup, you can run the command below.

```sh
docker compose up -d
```

### Docker Run Method

You can use the command below to setup the container without a compose file.

```sh
docker run -dit \
-v data:/home/steam/Unturned \
-p 27015:27015/tcp \
-p 27015:27015/udp \
-p 27016:27016/tcp \
-p 27016:27016/udp \
ghcr.io/brasscord-network/docker-unturned-server:vanilla  
```

Make sure to forward ports `27015` and `27016` on both TCP and UDP, or use the server code to direct connect.
Additional configurations can be done through mounting the volume or execing inside the container to use `nano` to edit configs.

## Runtime Model

- The container installs Unturned into `/home/steam/Unturned` on first boot.
- Existing installations are reused on restart.
- Updates are opt-in with `UPDATE_ON_START=true`.
- The server always launches with `+InternetServer/<SERVER_ID>`.
- Extra container command arguments are appended directly to the Unturned launch command.
- The server is launched through Unturned's `ServerHelper.sh`, with logs sent to container stdout.

## Supported Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `SERVER_ID` | `server` | Unturned server save/config directory and launch identifier. |
| `UPDATE_ON_START` | `false` | When `true`, runs SteamCMD `app_update` before launch. |
| `WORKSHOP_FILE_IDS` | empty | Comma-separated numeric Steam Workshop item IDs written to `Servers/<SERVER_ID>/WorkshopDownloadConfig.json`. |
| `STEAM_USERNAME` | empty | Optional Steam account name for authenticated installs. |
| `STEAM_PASSWORD` | empty | Optional Steam password. Must be set with `STEAM_USERNAME`. |
| `STEAM_GUARD_CODE` | empty | Optional Steam Guard code for authenticated installs. |

If `WORKSHOP_FILE_IDS` is unset or empty, the container leaves any existing `WorkshopDownloadConfig.json` untouched.

## Building Images

Build the vanilla image:

```sh
docker build --target vanilla -t docker-unturned-server:vanilla .
```

Build the LDM image variant:

```sh
docker build --target ldm -t docker-unturned-server:ldm .
```

The `ldm` target downloads `Rocket.Unturned.zip` from the GitHub release asset for `SmartlyDressedGames/Legally-Distinct-Missile` tag `v4.9.3.18` and installs it into `Modules/Rocket.Unturned` at container startup.

## Registry Publishing

The repository includes native publish pipelines for both GitHub and GitLab:

- GitHub Actions publishes to `ghcr.io/brasscord-network/docker-unturned-server`.
- GitLab CI/CD is maintained privately.

Both pipelines build the `vanilla` and `ldm` targets on pushes to `master`, on git tags, and on manual runs.
They are also wired for a weekly rebuild that uses `--pull` to refresh from the latest base image.

Weekly rebuild behavior:

- GitHub Actions runs every Sunday at `05:00 UTC` via the workflow cron schedule.
- The internal GitLab CI runs on scheduled pipelines

Published tags follow the same target-oriented pattern:

- `vanilla` and `ldm` on `master`
- `vanilla-<short-sha>` and `ldm-<short-sha>` on every publish
- `vanilla-<git-tag>` and `ldm-<git-tag>` on tagged releases

## Examples

Launch with extra Unturned args:

```sh
docker compose run --rm server -Port=27015
```

Use authenticated SteamCMD login:

```sh
docker run --rm \
  -e STEAM_USERNAME=example \
  -e STEAM_PASSWORD=example \
  -e STEAM_GUARD_CODE=12345 \
  -v data:/home/steam/Unturned \
  ghcr.io/brasscord-network/docker-unturned-server:vanilla
```

Set Workshop item IDs:

```sh
docker run --rm \
  -e WORKSHOP_FILE_IDS=123456789,987654321 \
  -v data:/home/steam/Unturned \
  ghcr.io/brasscord-network/docker-unturned-server:vanilla
```

## Credits

This project was originally forked from `ImperialPlugins/unturned-docker`.
Credit to the CM2 team for the `steamcmd` base image.

## License

This repository remains under the MIT license.
