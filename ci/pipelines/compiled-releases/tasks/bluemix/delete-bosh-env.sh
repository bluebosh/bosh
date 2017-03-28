#!/usr/bin/env bash

set -eux

source bosh-src/ci/pipelines/compiled-releases/tasks/utils.sh

check_param SL_VM_PREFIX
check_param SL_USERNAME
check_param SL_API_KEY
check_param SL_DATACENTER
check_param SL_VLAN_PUBLIC
check_param SL_VLAN_PRIVATE

#
# target/authenticate
#

tar -zxvf director-state/director-state.tgz -C director-state/
cat director-state/director-hosts >> /etc/hosts

BOSH_CLI="$(pwd)/$(echo bosh-cli/bosh-cli-*)"
chmod +x ${BOSH_CLI}

SL_VM_DOMAIN=${SL_VM_PREFIX}.softlayer.com
cp director-state/bosh-template.yml ./

$BOSH_CLI delete-env bosh-template.yml \
                      --vars-store director-state/credentials.yml \
                      -v SL_VM_PREFIX=${SL_VM_PREFIX} \
                      -v SL_VM_DOMAIN=${SL_VM_DOMAIN} \
                      -v SL_USERNAME=${SL_USERNAME} \
                      -v SL_API_KEY=${SL_API_KEY} \
                      -v SL_DATACENTER=${SL_DATACENTER} \
                      -v SL_VLAN_PUBLIC=${SL_VLAN_PUBLIC} \
                      -v SL_VLAN_PRIVATE=${SL_VLAN_PRIVATE}