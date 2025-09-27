#!/bin/sh
set -e;

: "${TEST_COVERAGE_DIR_PATH:=coverageReport}";
: "${TEST_COVERAGE_FILE_NAME:=coverage.out}";

USE_DOCKER=0;
RUNNING_IN_PIPELINE=0;
DOCKER_FLAG="";
CICD_FLAG="";

while [ "$#" -gt 0 ]; do
  case "$1" in
    --docker) USE_DOCKER=1; shift 1;;
    --cicd) RUNNING_IN_PIPELINE=1; USE_DOCKER=1; shift 1;;

    -*) echo "unknown option: $1" >&2; exit 1;;
  esac
done

if [ $USE_DOCKER -eq 1 ]; then
  DOCKER_FLAG="--docker";
fi
if [ $RUNNING_IN_PIPELINE -eq 1 ]; then
  CICD_FLAG="--cicd";
fi

if [ $USE_DOCKER -eq 0 ]; then
  rm -rf ./${TEST_COVERAGE_DIR_PATH};
fi

sh ./cli/test.sh --coverage $DOCKER_FLAG $CICD_FLAG;

CMD="go tool cover -html='${TEST_COVERAGE_DIR_PATH}/${TEST_COVERAGE_FILE_NAME}' -o '${TEST_COVERAGE_DIR_PATH}/coverage.html'";

if [ $USE_DOCKER -eq 1 ]; then
  INTERACTIVE_FLAGS="-it";
  if [ $RUNNING_IN_PIPELINE -eq 1 ]; then
    INTERACTIVE_FLAGS="-i";
  fi

  docker run --rm ${INTERACTIVE_FLAGS} -v "./:/app/" -w "/app/" -e GOTOOLCHAIN=local golang:1.25 /bin/sh -c "${CMD}";
else
  eval "${CMD}";
fi

# Normalize Go coverprofile paths (import paths) to repo filesystem paths under ./src
# Example line: github.com/org/repo/Api/foo.go:NN.MM,...
# We want:      src/Api/foo.go:NN.MM,...
# Handle all service modules under ./src/<service>/go.mod
for gm in ./src/*/go.mod; do
  svc="$(basename "$(dirname "${gm}")")";

  # Extract the repo root module prefix (everything before /<service>)
  root_prefix="$(sed -n 's/^module[[:space:]]\+\(.*\)\/'"${svc}"'$/\1/p' "${gm}")";
  if [ -z "${root_prefix}" ]; then
    continue;
  fi

  # Rewrite lines 2..end (skip the "mode: ..." header) in place
  # Replace "^github.com/org/repo/<service>/" with "src/<service>/"
  sed -E -i '2,$ s#^'"${root_prefix}"'/'"${svc}"'/#src/'"${svc}"'/#' "${TEST_COVERAGE_DIR_PATH}/${TEST_COVERAGE_FILE_NAME}";
done
