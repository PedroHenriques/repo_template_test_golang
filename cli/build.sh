#!/bin/sh
set -e;

PROJ="";

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag) IMAGE_TAG="${2}"; shift 2;;
    --proj) PROJECT_NAME="${2}"; shift 2;;
    --cicd) shift 1;;

    -*) echo "unknown option: $1" >&2; exit 1;;
    *) PROJ="${PROJ}$1 "; shift 1;;
  esac
done

export IMAGE_TAG;
export PROJECT_NAME;

docker compose -f setup/local/docker-compose.yml -p myapp build $PROJ;