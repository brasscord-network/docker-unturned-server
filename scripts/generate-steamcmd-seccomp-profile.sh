#!/usr/bin/env bash

set -euo pipefail

DEFAULT_SOURCE_URL="https://raw.githubusercontent.com/moby/profiles/main/seccomp/default.json"
OUTPUT_PATH="${1:-./steamcmd-seccomp.json}"
SOURCE_URL="${SECCOMP_PROFILE_SOURCE_URL:-$DEFAULT_SOURCE_URL}"

require_command() {
    local name="$1"

    if ! command -v "$name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$name" >&2
        exit 1
    fi
}

require_command curl
require_command python3

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

source_json="$tmp_dir/default.json"

curl -fsSL "$SOURCE_URL" -o "$source_json"
mkdir -p "$(dirname "$OUTPUT_PATH")"

python3 - "$source_json" "$OUTPUT_PATH" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

with source_path.open("r", encoding="utf-8") as handle:
    profile = json.load(handle)

syscalls = profile.get("syscalls", [])

socketcall_updated = False
af_alg_rule_present = False
insert_index = len(syscalls)

for index, rule in enumerate(syscalls):
    names = rule.get("names", [])
    if names == ["socketcall"]:
        rule["action"] = "SCMP_ACT_ALLOW"
        rule.pop("errnoRet", None)
        socketcall_updated = True

    if names != ["socket"]:
        continue

    args = rule.get("args", [])
    if not args:
        continue

    arg0 = args[0]
    if (
        rule.get("action") == "SCMP_ACT_ALLOW"
        and arg0.get("index") == 0
        and arg0.get("value") == 38
        and arg0.get("op") == "SCMP_CMP_EQ"
    ):
        af_alg_rule_present = True

    if (
        insert_index == len(syscalls)
        and arg0.get("index") == 0
        and arg0.get("value") == 39
        and arg0.get("op") == "SCMP_CMP_EQ"
    ):
        insert_index = index

if not socketcall_updated:
    syscalls.append({"names": ["socketcall"], "action": "SCMP_ACT_ALLOW"})

if not af_alg_rule_present:
    syscalls.insert(
        insert_index,
        {
            "names": ["socket"],
            "action": "SCMP_ACT_ALLOW",
            "args": [{"index": 0, "value": 38, "op": "SCMP_CMP_EQ"}],
        },
    )

with output_path.open("w", encoding="utf-8") as handle:
    json.dump(profile, handle, indent=2)
    handle.write("\n")
PY

printf 'Wrote SteamCMD seccomp profile to %s\n' "$OUTPUT_PATH"
printf 'Use it with: --security-opt seccomp=%s\n' "$OUTPUT_PATH"
