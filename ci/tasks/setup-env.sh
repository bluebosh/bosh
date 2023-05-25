#!/bin/bash -exu

main() {
  source bosh-src/ci/tasks/utils.sh

  local build_dir="${PWD}"
  local bbl_state_env_repo_dir=$PWD/bbl-state
  local output_dir="$PWD/updated-bbl-state/"
  local env_assets="$PWD/bosh-src/ci/acceptance"
  BBL_STATE_DIR=bosh-acceptance-env
  export BBL_STATE_DIR

  trap "commit_bbl_state_dir ${bbl_state_env_repo_dir} ${BBL_STATE_DIR} ${output_dir} 'Update bosh-acceptance-env environment'" EXIT

  mkdir -p "bbl-state/${BBL_STATE_DIR}"

  pushd "bbl-state/${BBL_STATE_DIR}"
    bbl version
    bbl plan > bbl_plan.txt

    # Customize environment
    cp $env_assets/*.sh .

    rm -rf bosh-deployment
    ln -s ${build_dir}/bosh-deployment bosh-deployment

    rotate_bbl_certs vars/*store.yml

    bbl --debug up

    set +x
    eval "$(bbl print-env)"
    set -x

    rotate_credhub_certs

    bosh upload-stemcell ${build_dir}/stemcell/*.tgz -n
    bosh -d zookeeper deploy --fix --recreate ${build_dir}/zookeeper-release/manifests/zookeeper.yml -n

    bosh -d prometheus deploy --fix --recreate prometheus.yml \
      -l vars/director-vars-store.yml \
      -l vars/director-vars-file.yml \
      --var="prometheus_release_tgz=${build_dir}/prometheus-boshrelease/release.tgz" \
      --var="prometheus_release_version=$(cat "${build_dir}/prometheus-boshrelease/version")" \
      --vars-store=vars/prometheus-vars-store.yml \
      -n
  popd
}

main "$@"
