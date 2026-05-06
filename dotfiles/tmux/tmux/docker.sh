#!/bin/sh
# Count running docker containers; silent fallback if docker is unavailable.
command -v docker >/dev/null 2>&1 || { printf "0"; exit 0; }
n=$(docker ps -q 2>/dev/null | grep -c .)
printf "%s" "${n:-0}"
