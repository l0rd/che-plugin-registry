#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# Output command before executing
set -x

# Exit on error
set -e

# Source environment variables of the jenkins slave
# that might interest this worker.
function load_jenkins_vars() {
  if [ -e "jenkins-env.json" ]; then
    eval "$(./env-toolkit load -f jenkins-env.json \
            DEVSHIFT_TAG_LEN \
            QUAY_ECLIPSE_CHE_USERNAME \
            QUAY_ECLIPSE_CHE_PASSWORD \
            JENKINS_URL \
            GIT_BRANCH \
            GIT_COMMIT \
            BUILD_NUMBER \
            ghprbSourceBranch \
            ghprbActualCommit \
            BUILD_URL \
            ghprbPullId)"
  fi
}

function install_deps() {
  # We need to disable selinux for now, XXX
  /usr/sbin/setenforce 0  || true

  # Get all the deps in
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce \
    git

  service docker start
  echo 'CICO: Dependencies installed'
}

function tag_push() {
  local TARGET=$1
  docker tag "${IMAGE}" "$TARGET"
  docker push "$TARGET"
}

function build_and_push() {
  DOCKERFILE="Dockerfile"
  REGISTRY="quay.io"
  ORGANIZATION="eclipse"
  IMAGE="che-plugin-registry"
  TAG="nightly"

  if [ -n "${QUAY_ECLIPSE_CHE_USERNAME}" ] && [ -n "${QUAY_ECLIPSE_CHE_PASSWORD}" ]; then
    docker login -u "${QUAY_ECLIPSE_CHE_USERNAME}" -p "${QUAY_ECLIPSE_CHE_PASSWORD}" "${REGISTRY}"
  else
    echo "Could not login, missing credentials for pushing to the '${ORGANIZATION}' organization"
  fi

  # Let's build and push images to 'quay.io'
  docker build -t ${IMAGE} -f ${DOCKERFILE} .
  tag_push "${REGISTRY}/${ORGANIZATION}/$IMAGE:$TAG"
  echo "CICO: nightly images pushed to 'quay.io/eclipse' organization"
}

function cico_setup() {
  load_jenkins_vars;
  install_deps;
}
cico_setup
build_and_push
