#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <simv> [simv-args...]" >&2
    exit 2
fi

SIMV="$1"
shift

CONTAINER_NAME="${VCS_LXC_CONTAINER:-almalinux8}"
CONTAINER_USER="${VCS_LXC_USER:-yusen}"

CONTAINER_STATUS=$(sudo lxc-info -n "${CONTAINER_NAME}" -s | awk '{print $2}')
if [ "${CONTAINER_STATUS}" != "RUNNING" ]; then
    sudo lxc-start -n "${CONTAINER_NAME}" -d
fi

CURRENT_DIR=$(pwd)
CURRENT_DIR_QUOTED=$(printf "%q" "${CURRENT_DIR}")
SIMV_QUOTED=$(printf "%q" "${SIMV}")
ARGS_QUOTED=$(printf " %q" "$@")

sudo lxc-attach -n "${CONTAINER_NAME}" --clear-env -- /bin/su - "${CONTAINER_USER}" -c "
    cd ${CURRENT_DIR_QUOTED} 2>/dev/null || cd /home/${CONTAINER_USER}
    exec ${SIMV_QUOTED}${ARGS_QUOTED}
"
