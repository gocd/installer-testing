#!/usr/bin/env bash

if [ $# -ne 2 ] || { [ "$1" != "server" ] && [ "$1" != "agent" ]; }; then
    echo " Please provide the following arguments server|agent start|stop"
    exit 1
fi

service="go-$1"
action="$2"

set -euo pipefail

# On a failed start, dump the relevant wrapper log to aid debugging, while
# retaining the original command's exit code.
dump_wrapper_log_on_failure() {
    exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$action" == "start" ]; then
        wrapper_log="/var/log/$service/$service-wrapper.log"
        echo " Start of $service failed with exit code $exit_code, dumping $wrapper_log"
        cat "$wrapper_log" || true # don't let a missing log clobber the original exit code under set -e
    fi
    exit "$exit_code"
}
trap dump_wrapper_log_on_failure EXIT

if [ -f "/etc/systemd/system/$service.service" ]; then
    echo " Using systemctl to $action $service "
    systemctl "$action" "$service"
else
    echo " Trying to $action $service without direct service usage."
    "/usr/share/$service/bin/$service" "$action"
fi
