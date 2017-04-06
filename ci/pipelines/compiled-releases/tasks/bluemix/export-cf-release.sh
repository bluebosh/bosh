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

DIRECTOR=$(cat director-state/director-hosts |awk '{print $1}')
DIRECTOR_UUID=$(cat director-state/bosh-template-state.json |grep director_id| cut -d"\"" -f4)
DIRECTOR_PASSWORD=$($BOSH_CLI int director-state/credentials.yml --path /DI_ADMIN_PASSWORD)
STEMCELL_NAME=$($BOSH_CLI -e bosh-env stemcells|grep ubuntu-trusty|awk '{print $1}')
STEMCELL_VERSION=$(cat stemcell/version)
SL_VM_DOMAIN=${SL_VM_PREFIX}.softlayer.com
deployment_dir="${PWD}/cf-deployment"
manifest_filename="cf-manifest.yml"
deployment_name=compiled-cf
mkdir -p $deployment_dir

$BOSH_CLI int bosh-src/ci/pipelines/compiled-releases/templates/bluemix-template.yml \
                                                        -v director_password=${DIRECTOR_PASSWORD} \
                                                        -v director_ip=${DIRECTOR} \
                                                        -v director_pub_ip=${DIRECTOR} \
                                                        -v director_uuid=${DIRECTOR_UUID} \
                                                        -v deploy_name=${deployment_name} \
                                                        -v data_center_name=${SL_DATACENTER} \
                                                        -v private_vlan_id=${SL_VLAN_PRIVATE} \
                                                        -v public_vlan_id=${SL_VLAN_PUBLIC} \
                                                        -v stemcell_version=${STEMCELL_VERSION} \
                                                        -v cf-release=${cf_release} \
                                                        -v cf-release-version=${cf_release_version} \
                                                        -v cf-services-release=${cf_services_release} \
                                                        -v cf-services-release-version=${cf_services_release_version} \
                                                        -v cf-services-contrib-release=${cf_services_contrib_release} \
                                                        -v cf-services-contrib-release-version=${cf_services_contrib_release_version} \
                                                        -v mod_vms_release=${mod_vms_release} \
                                                        -v mod_vms_release_version=${mod_vms_release_version} \
                                                        -v security_release=${security_release} \
                                                        -v security_release_version=${security_release_version} \
                                                        -v admin_ui_release=${admin_ui_release} \
                                                        -v admin_ui_release_version=${admin_ui_release_version} \
                                                        -v habr_release=${habr_release} \
                                                        -v habr_release_version=${habr_release_version} \
                                                        -v loginserver_release=${loginserver_release} \
                                                        -v loginserver_release_version=${loginserver_release_version} \
                                                        -v marmot_logstash_forwarder_release=${marmot_logstash_forwarder_release} \
                                                        -v marmot_logstash_forwarder_release_version=${marmot_logstash_forwarder_release_version} \
                                                        -v unbound_release=${unbound_release} \
                                                        -v unbound_release_version=${unbound_release_version} \
                                                        > ${deployment_dir}/${manifest_filename}
#
# upload releases
#
releases=$($BOSH_CLI int ${deployment_dir}/${manifest_filename} --path /releases |grep -Po '(?<=- location: ).*')
while IFS= read -r line; do
$BOSH_CLI -e bosh-env upload-release $line
done <<< "$releases"

#
# deploy and export
#
$BOSH_CLI -e bosh-env -d ${deployment_name} releases
$BOSH_CLI -e bosh-env -d ${deployment_name} deploy ${deployment_dir}/${manifest_filename} --no-redact -n
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${cf_release}/${cf_release_version} ubuntu-trusty/${STEMCELL_VERSION}
#$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${cf_services_release}/${cf_services_release_version} ubuntu-trusty/${STEMCELL_VERSION}
#$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${cf_services_contrib_release}/${cf_services_contrib_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${mod_vms_release}/${mod_vms_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${security_release}/${security_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${admin_ui_release}/${admin_ui_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${habr_release}/${habr_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${loginserver_release}/${loginserver_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${marmot_logstash_forwarder_release}/${marmot_logstash_forwarder_release_version} ubuntu-trusty/${STEMCELL_VERSION}
$BOSH_CLI -e bosh-env -d ${deployment_name} export-release ${unbound_release}/${unbound_release_version} ubuntu-trusty/${STEMCELL_VERSION}

mkdir -p compiled-release/cf
cp *.tgz compiled-release/cf/
for package_name in `ls | grep tgz`
do
  shasum1 compiled-release/cf/${package_name}
done