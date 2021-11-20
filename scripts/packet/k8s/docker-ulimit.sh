#!/bin/bash

mkdir -p /etc/docker

echo \
'{
    "default-ulimits": {
        "memlock":
        {
            "name": "memlock",
            "soft": 67108864,
            "hard": 67108864
        }
    }
}' >/etc/docker/daemon.json
