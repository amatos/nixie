#!/usr/bin/env bash
# npbs-all — run nixpull + nixbuild + nixswitch on all hosts simultaneously.
# Codex (local darwin) runs in-process; NixOS hosts connect via SSH.
#
# Output from every host streams live, prefixed with [hostname].
# The script exits non-zero if any host fails.

set -uo pipefail

REMOTE_HOSTS=(gammu porkchop huginn)

# npbs is a shell alias (only active in interactive sessions). Expand it
# inline using the fish functions nixbuild and nixswitch, which are proper
# function files and auto-load in non-interactive fish as well.
NPBS_CMD='cd ~/Projects/nixie; and git pull; and nixbuild; and nixswitch'

# Runs npbs on a remote NixOS host over SSH.
run_remote() {
    local host="$1"
    ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=15 \
        "$host" "fish -c '$NPBS_CMD'" 2>&1 \
        | while IFS= read -r line; do
            printf '[%s] %s\n' "$host" "$line"
          done
    return "${PIPESTATUS[0]}"
}

# Runs npbs locally (codex/darwin — no SSH required).
run_local() {
    fish -c "$NPBS_CMD" 2>&1 \
        | while IFS= read -r line; do
            printf '[codex] %s\n' "$line"
          done
    return "${PIPESTATUS[0]}"
}

ALL_HOSTS=(codex "${REMOTE_HOSTS[@]}")
printf 'Updating %d hosts in parallel: %s\n\n' "${#ALL_HOSTS[@]}" "${ALL_HOSTS[*]}"

declare -A pids
run_local &
pids[codex]=$!
for host in "${REMOTE_HOSTS[@]}"; do
    run_remote "$host" &
    pids["$host"]=$!
done

failed=()
for host in "${ALL_HOSTS[@]}"; do
    if ! wait "${pids[$host]}"; then
        failed+=("$host")
    fi
done

echo ""
if (( ${#failed[@]} > 0 )); then
    printf 'FAILED: %s\n' "${failed[*]}" >&2
    exit 1
fi

echo "All hosts updated successfully."
