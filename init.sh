#!/usr/bin/env bash

set -euo pipefail

GAME_INSTALL_DIR="${GAME_INSTALL_DIR:-/home/steam/Unturned}"
SERVER_ID="${SERVER_ID:-server}"
STEAMCMD_DIR="${STEAMCMD_DIR:-/home/steam/steamcmd}"
STEAM_USERNAME="${STEAM_USERNAME:-}"
STEAM_PASSWORD="${STEAM_PASSWORD:-}"
STEAM_GUARD_CODE="${STEAM_GUARD_CODE:-}"
UPDATE_ON_START="$(printf '%s' "${UPDATE_ON_START:-false}" | tr '[:upper:]' '[:lower:]')"
WORKSHOP_FILE_IDS="${WORKSHOP_FILE_IDS:-}"
LDM_ENABLED="$(printf '%s' "${LDM_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
LDM_INSTALL_DIR="${LDM_INSTALL_DIR:-/opt/ldm}"
LDM_VERSION="${LDM_VERSION:-unknown}"

log() {
    printf '[init] %s\n' "$*"
}

fail() {
    printf '[init] ERROR: %s\n' "$*" >&2
    exit 1
}

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

steamcmd_log_has_docker_seccomp_error() {
    local log_path="$1"

    grep -Fq 'CreateBoundSocket: failed to create socket, error [no name available] (38)' "$log_path"
}

fail_for_docker_seccomp_error() {
    cat >&2 <<'EOF'
[init] ERROR: SteamCMD failed because Docker's seccomp profile blocked the socket path it needs.
[init] ERROR: This is currently known to affect Docker Engine 29.4.2 with the built-in seccomp profile.
[init] ERROR: Start the container with a custom seccomp profile that re-allows AF_ALG (family 38) and socketcall,
[init] ERROR: or use the less restrictive temporary fallback `--security-opt seccomp=unconfined`.
[init] ERROR: Repository workaround instructions:
[init] ERROR: https://github.com/brasscord-network/docker-unturned-server#docker-2942-steamcmd-workaround
EOF
    exit 1
}

validate_environment() {
    if [[ -z "$SERVER_ID" ]]; then
        fail "SERVER_ID must not be empty."
    fi

    case "$UPDATE_ON_START" in
        true|false) ;;
        *)
            fail "UPDATE_ON_START must be either 'true' or 'false'."
            ;;
    esac

    case "$LDM_ENABLED" in
        true|false) ;;
        *)
            fail "LDM_ENABLED must be either 'true' or 'false'."
            ;;
    esac

    if [[ -n "$STEAM_USERNAME" || -n "$STEAM_PASSWORD" ]]; then
        if [[ -z "$STEAM_USERNAME" || -z "$STEAM_PASSWORD" ]]; then
            fail "STEAM_USERNAME and STEAM_PASSWORD must be provided together."
        fi
    fi
}

run_steamcmd_app_update() {
    local -a steamcmd_args=(
        bash "$STEAMCMD_DIR/steamcmd.sh"
        +force_install_dir "$GAME_INSTALL_DIR"
    )
    local attempt
    local max_attempts=2
    local steamcmd_log

    if [[ -n "$STEAM_USERNAME" ]]; then
        log "Using authenticated SteamCMD login for ${STEAM_USERNAME}."
        steamcmd_args+=(+login "$STEAM_USERNAME" "$STEAM_PASSWORD")
        if [[ -n "$STEAM_GUARD_CODE" ]]; then
            steamcmd_args+=("$STEAM_GUARD_CODE")
        fi
    else
        log "Using anonymous SteamCMD login."
        steamcmd_args+=(+login anonymous)
    fi

    steamcmd_args+=(
        +@sSteamCmdForcePlatformBitness 64
        +app_update 1110390
        +quit
    )

    for attempt in $(seq 1 "$max_attempts"); do
        if (( attempt > 1 )); then
            log "Retrying SteamCMD app_update (attempt ${attempt} of ${max_attempts})."
        fi

        steamcmd_log="$(mktemp)"

        if "${steamcmd_args[@]}" > >(tee "$steamcmd_log") 2> >(tee -a "$steamcmd_log" >&2); then
            rm -f "$steamcmd_log"
            return
        fi

        if steamcmd_log_has_docker_seccomp_error "$steamcmd_log"; then
            rm -f "$steamcmd_log"
            fail_for_docker_seccomp_error
        fi

        rm -f "$steamcmd_log"

        if (( attempt < max_attempts )); then
            if [[ -f "$GAME_INSTALL_DIR/steamapps/appmanifest_1110390.acf" ]]; then
                rm "$GAME_INSTALL_DIR/steamapps/appmanifest_1110390.acf"
            fi
            log "SteamCMD app_update failed on attempt ${attempt}; retrying after a short delay."
            sleep 3
        fi
    done

    fail "SteamCMD app_update failed after ${max_attempts} attempts."
}

ensure_server_installation() {
    mkdir -p "$GAME_INSTALL_DIR"

    if [[ ! -x "$GAME_INSTALL_DIR/Unturned_Headless.x86_64" ]]; then
        log "Installing Unturned dedicated server into $GAME_INSTALL_DIR."
        run_steamcmd_app_update
        return
    fi

    if [[ "$UPDATE_ON_START" == "true" ]]; then
        log "Updating Unturned dedicated server in $GAME_INSTALL_DIR."
        run_steamcmd_app_update
        return
    fi

    log "Skipping SteamCMD update because UPDATE_ON_START=false."
}

configure_server_state() {
    local server_dir="$GAME_INSTALL_DIR/Servers/$SERVER_ID"

    mkdir -p "$server_dir" "$GAME_INSTALL_DIR/Modules"
}

configure_workshop() {
    local has_workshop_ids="${WORKSHOP_FILE_IDS//[[:space:]]/}"
    local server_dir="$GAME_INSTALL_DIR/Servers/$SERVER_ID"
    local -a ids=()
    local raw_id
    local rendered_ids=""
    local workshop_count=0

    if [[ -z "$has_workshop_ids" ]]; then
        log "No WORKSHOP_FILE_IDS provided; leaving existing workshop config unchanged."
        return
    fi

    IFS=',' read -r -a ids <<< "$WORKSHOP_FILE_IDS"

    for raw_id in "${ids[@]}"; do
        raw_id="$(trim_whitespace "$raw_id")"

        if [[ -z "$raw_id" ]]; then
            fail "WORKSHOP_FILE_IDS contains an empty item."
        fi

        if [[ ! "$raw_id" =~ ^[0-9]+$ ]]; then
            fail "WORKSHOP_FILE_IDS must contain only comma-separated numeric item IDs."
        fi

        if [[ -n "$rendered_ids" ]]; then
            rendered_ids+=", "
        fi

        rendered_ids+="$raw_id"
        workshop_count=$((workshop_count + 1))
    done

    cat > "$server_dir/WorkshopDownloadConfig.json" <<EOF
{
  "File_IDs": [${rendered_ids}],
  "Ignore_Children_File_IDs": [],
  "Query_Cache_Max_Age_Seconds": 600,
  "Max_Query_Retries": 2,
  "Use_Cached_Downloads": true,
  "Should_Monitor_Updates": true,
  "Shutdown_Update_Detected_Timer": 600,
  "Shutdown_Update_Detected_Message": "Workshop file update detected, shutdown in: {0}",
  "Shutdown_Kick_Message": "Shutdown for Workshop file update."
}
EOF

    log "Wrote WorkshopDownloadConfig.json with ${workshop_count} Workshop item(s)."
}

install_ldm_variant() {
    if [[ "$LDM_ENABLED" != "true" ]]; then
        return
    fi

    if [[ ! -f "$LDM_INSTALL_DIR/Rocket.Unturned/Rocket.Unturned.module" ]]; then
        fail "LDM is enabled but no extracted Rocket.Unturned module was found in $LDM_INSTALL_DIR."
    fi

    rm -rf "$GAME_INSTALL_DIR/Modules/Rocket.Unturned"
    cp -R "$LDM_INSTALL_DIR/Rocket.Unturned" "$GAME_INSTALL_DIR/Modules/Rocket.Unturned"
    log "Installed Legally Distinct Missile ${LDM_VERSION} into Modules/Rocket.Unturned."
}

launch_server() {
    local server_arg="+InternetServer/$SERVER_ID"

    cd "$GAME_INSTALL_DIR"
    chmod +x ./ServerHelper.sh
    ulimit -n 2048

    log "Launching Unturned with ${server_arg}."
    exec ./ServerHelper.sh -logFile - "$server_arg" "$@"
}

main() {
    validate_environment
    ensure_server_installation
    configure_server_state
    configure_workshop
    install_ldm_variant
    launch_server "$@"
}

main "$@"
