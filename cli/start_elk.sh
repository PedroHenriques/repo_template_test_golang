#!/bin/sh
set -e;

COMPOSE_PROFILES="${COMPOSE_PROFILES:-}";
RUNNING_IN_PIPELINE=0;
KEPT_ARGS="";

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cicd) RUNNING_IN_PIPELINE=1; shift 1;;

    *) KEPT_ARGS="$KEPT_ARGS '$(printf %s "${1}" | sed "s/'/'\\\\''/g")'"; shift;; # append a single-quoted, safely-escaped copy of "$1"
  esac
done

# reset positional params to the kept args (preserves spaces/special chars)
eval "set -- ${KEPT_ARGS}";

if [ ${RUNNING_IN_PIPELINE} -eq 1 ]; then
  COMPOSE_PROFILES="$(printf %s "$COMPOSE_PROFILES" | sed -E 's/(^|,)only_if_not_cicd(,|$)/\1\2/g; s/,,+/,/g; s/^,//; s/,$//')";
else
  if [ -z "$COMPOSE_PROFILES" ]; then
    COMPOSE_PROFILES="only_if_not_cicd";
  else
    COMPOSE_PROFILES="${COMPOSE_PROFILES},only_if_not_cicd";
  fi
fi

docker network create myapp_shared || true;

docker compose -f setup/local/docker-compose.elk.yml -p myapp_elk up --no-build "$@";