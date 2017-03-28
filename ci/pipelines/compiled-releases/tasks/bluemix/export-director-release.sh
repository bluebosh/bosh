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

echo "Trying to set target to director..."

$BOSH_CLI  -e $(cat director-state/director-hosts |awk '{print $2}') --ca-cert <($BOSH_CLI int director-state/credentials.yml --path /DIRECTOR_SSL/ca ) alias-env bosh-env

echo "Trying to login to director..."

export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(${BOSH_CLI} int director-state/credentials.yml --path /DI_ADMIN_PASSWORD)

$BOSH_CLI -e bosh-env login

ls -al
ls -al stemcell

$BOSH_CLI -e bosh-env upload-stemcell stemcell/light-bosh-stemcell-*.tgz
$BOSH_CLI -e bosh-env upload-release bosh-release/release.tgz
$BOSH_CLI -e bosh-env upload-release bosh-softlayer-cpi-release/release.tgz

DIRECTOR=$(cat director-state/director-hosts |awk '{print $1}')
DIRECTOR_UUID=$(cat director-deploy-state.json |grep director_id| cut -d"\"" -f4)
BOSH_VERSION=$(cat bosh-release/version)
CPI_VERSION=$(cat bosh-softlayer-cpi-release/version)
STEMCELL_NAME=$($BOSH_CLI -e bosh-env stemcells|grep ubuntu-trusty|awk '{print $1}')
STEMCELL_VERSION=$(cat stemcell/version)
SL_VM_DOMAIN=${SL_VM_PREFIX}.softlayer.com
deployment_dir="${PWD}/director-deployment"
manifest_filename="director-manifest.yml"

mkdir -p $deployment_dir

cat > "${deployment_dir}/${manifest_filename}"<<EOF
---
name: compile-bosh-release
director_uuid: ${DIRECTOR_UUID}

releases:
- name: bosh
  version: latest
- name: bosh-softlayer-cpi
  version: latest

compilation:
  workers: 1
  network: default
  reuse_compilation_vms: true
  cloud_properties:
    Bosh_ip:  ${DIRECTOR}
    Datacenter: { Name:  ${SL_DATACENTER}  }
    PrimaryNetworkComponent: { NetworkVlan: { Id:  ${SL_VLAN_PUBLIC} } }
    PrimaryBackendNetworkComponent: { NetworkVlan: { Id:  ${SL_VLAN_PRIVATE} } }
    VmNamePrefix:  compile-bosh-release-worker-
    EphemeralDiskSize: 100
    HourlyBillingFlag: true

disk_pools:
- name: disks
  disk_size: 20_000

networks:
- name: default
  type: dynamic
  dns:
  - ${DIRECTOR}
  - 8.8.8.8
  - 10.0.80.11
  - 10.0.80.12
  cloud_properties:
    security_groups:
    - default
    - cf

resource_pools:
- name: coreNode
  network: default
  size: 1
  stemcell:
      name: ${STEMCELL_NAME}
      version: latest
  cloud_properties:
      Bosh_ip:  ${DIRECTOR}
      StartCpus:  8
      MaxMemory:  8192
      Datacenter: { Name:  ${SL_DATACENTER}  }
      PrimaryNetworkComponent: { NetworkVlan: { Id:  ${SL_VLAN_PUBLIC} } }
      PrimaryBackendNetworkComponent: { NetworkVlan: { Id:  ${SL_VLAN_PRIVATE} } }
      VmNamePrefix:  compile-bosh-release-core-
      EphemeralDiskSize: 100
      HourlyBillingFlag: true

jobs: []

update:
  canaries: 1
  max_in_flight: 1
  canary_watch_time: 1000-90000
  update_watch_time: 1000-90000
EOF

#
# deploy and export
#

deployment_name=compile-bosh-release
$BOSH_CLI -e bosh-env -d ${deployment_name} deploy ${deployment_dir}/${manifest_filename} --no-redact -n
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release bosh/${BOSH_VERSION} ubuntu-trusty/${STEMCELL_VERSION}

mkdir -p compiled-release/bosh
cp bosh-${BOSH_VERSION}-ubuntu-trusty-${STEMCELL_VERSION}-*.tgz compiled-release/bosh/
sha1sum compiled-release/bosh/*.tgz
