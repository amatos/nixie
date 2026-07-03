#!/usr/bin/env bash
# npbs-all — run 'npbs' (nixpull + nixbuild + nixswitch) on all remote hosts
# simultaneously from codex. SSH keys and host connectivity must be in place.
#
# Output from every host streams live, prefixed with [hostname].
# The script exits non-zero if any host fails.

set -uo pipefail

HOSTS=(gammu porkchop huginn)

# Runs npbs on a single host, prefixing every output line with [host].
# Returns the SSH exit code so failures are detected by the caller.
run_host() {
    local host="$1"
    ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=15 \
        "$host" 'fish -c npbs' 2>&1 \
        | while IFS= read -r line; do
            printf '[%s] %s\n' "$host" "$line"
          done
    return "${PIPESTATUS[0]}"
}

printf 'Updating %d hosts in parallel: %s\n\n' "${#HOSTS[@]}" "${HOSTS[*]}"

declare -A pids
for host in "${HOSTS[@]}"; do
    run_host "$host" &
    pids["$host"]=$!
done

failed=()
for host in "${HOSTS[@]}"; do
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
