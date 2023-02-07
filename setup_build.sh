#!/bin/bash

# Set up the environment for the main build
BUILD_TAG=latest
if [[ -n "${CIRCLE_TAG}" ]]; then
    BUILD_TAG="${CIRCLE_TAG}"
fi
export BUILD_TAG

do_build() {

    DOCKER_BUILDKIT=1 \
    BUILDKIT_PROGRESS=plain \
    docker build -t \
        pennlinc/aslprep_build:${BUILD_TAG} \
        .

}
