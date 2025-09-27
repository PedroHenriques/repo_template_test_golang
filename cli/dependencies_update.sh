#!/bin/sh
set -e;

UPDATE=0;
UPDATE_PROMPT=1;
USE_DOCKER=0;
RUNNING_IN_PIPELINE=0;

while [ "$#" -gt 0 ]; do
  case "$1" in
    -u|--update) UPDATE=1; shift 1;;
    -y) UPDATE_PROMPT=0; shift 1;;
    --docker) USE_DOCKER=1; shift 1;;
    --cicd) RUNNING_IN_PIPELINE=1; USE_DOCKER=1; shift 1;;

    -*) echo "unknown option: $1" >&2; exit 1;;
  esac
done

OPTS="";
if [ $UPDATE -eq 1 ]; then
  OPTS="go get -u ./... && go mod tidy";
else
  OPTS="go list -m -u all";
fi

CMD="set -e;
mods=\$(find ./src -type f -name go.mod | sort);
for m in \$mods; do
  dir=\$(dirname \"\$m\");
  echo \"📦 \${dir}\";
  (cd \"\$dir\" && ${OPTS});
done;
[ -f go.work ] && go work sync || true"
if [ $USE_DOCKER -eq 1 ]; then
  INTERACTIVE_FLAGS="-it";
  if [ $RUNNING_IN_PIPELINE -eq 1 ]; then
    INTERACTIVE_FLAGS="-i";
  fi

  docker run --rm ${INTERACTIVE_FLAGS} -v "./:/app/" -w "/app/" -e GOTOOLCHAIN=local golang:1.25 /bin/sh -c "${CMD}";
else
  eval "${CMD}";
fi