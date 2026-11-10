#!/bin/bash
# Healthy only when IB Gateway itself is listening on its API port, which it opens
# after a successful login. socat's published port (4003/4004) accepts connections
# whether or not a Gateway is logged in behind it, so it can't tell a live session
# from a lapsed one; this check can. It reads the kernel's socket table instead of
# connecting, so it leaves nothing in the Gateway's API log.
set -euo pipefail

case "${TRADING_MODE:-paper}" in
live) ports=(4001) ;;
both) ports=(4001 4002) ;;
*) ports=(4002) ;;
esac
[ "${DUAL_MODE:-no}" = "yes" ] && ports=(4001 4002)

for port in "${ports[@]}"; do
	hex=$(printf '%04X' "$port")
	# field 2 = local address:port (hex), field 4 = state, 0A = LISTEN
	if ! awk -v p=":$hex" 'NR > 1 && $4 == "0A" && substr($2, length($2) - 4) == p { f = 1 } END { exit !f }' \
		/proc/net/tcp /proc/net/tcp6 2>/dev/null; then
		echo "IB Gateway API port $port is not listening (not logged in?)"
		exit 1
	fi
done
echo "IB Gateway API listening on ${ports[*]}"
