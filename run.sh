#!/bin/bash
set -e
REPO=$1
SHA=${2:-master}
REGISTRY=$3
TOKEN=$4

echo Repo:$REPO
echo Sha:$SHA
echo Registry:$REGISTRY
echo Token:$TOKEN

CONTAINER_NAME=app-$SHA-build
IMAGE_NAME=app-$SHA-ci
BUILD_PATH=build-$SHA

# clean up
rm -rf $BUILD_PATH

# checkout sha commit from github repo
docker build -t $IMAGE_NAME https://github.com/$REPO#$SHA -f Dockerfile.ci --no-cache
docker rm --force $(docker ps -qa --filter "name=${CONTAINER_NAME}") > /dev/null 2>&1 || true

docker create --name $CONTAINER_NAME $IMAGE_NAME echo ""
docker cp $CONTAINER_NAME:/app ./$BUILD_PATH

pushd $BUILD_PATH

export TAG=$SHA
export REGISTRY=$REGISTRY
export CI_TOKEN=$TOKEN

docker-compose -f docker-compose.ci.yml build
if [ ! -z $REGISTRY ]; then docker-compose -f docker-compose.ci.yml push; fi
if [ ! -z $TOKEN ]; then docker stack deploy -c ./docker/swarm/docker-compose.yml stack; fi

popd

# clean up
docker rmi -f $IMAGE_NAME
rm -rf $BUILD_PATH