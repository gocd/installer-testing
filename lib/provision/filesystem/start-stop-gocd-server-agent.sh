#!/usr/bin/env bash

if [ $# -ne 2 ]; then
    echo " Please provide the following arguments server|agent start|stop"
    exit 1
fi

if [ $1 -eq "agent" ]; then  

    if [ -f "/etc/init.d/go-agent" ]; then
        echo " Using /etc/init.d/go-agent to $2 agent "
        /etc/init.d/go-agent $2
    elif [ -f "/etc/systemd/system/go-agent.service" ]; then
        echo " Using systemctl to $2 agent "
        systemctl $2 go-agent
    elif [ -f "/etc/init/go-agent.conf" ]; then
        echo " Using upstart to $2 agent "
        $2 go-agent
    fi

elif [ $1 -eq "server" ]; then  

    if [ -f "/etc/init.d/go-server" ]; then
        echo " Using /etc/init.d/go-server to $2 server "
        /etc/init.d/go-server $2
    elif [ -f "/etc/systemd/system/go-server.service" ]; then
        echo " Using systemctl to $2 server "
        systemctl $2 go-server
    elif [ -f "/etc/init/go-server.conf" ]; then
        echo " Using upstart to $2 server "
        $2 go-server
    fi


fi

