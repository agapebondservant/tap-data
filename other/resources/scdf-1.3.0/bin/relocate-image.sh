#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && cd .. && pwd)"
DATA_FLOW_IMAGE_DIR="${BASE_DIR}/apps/data-flow/images"
SKIPPER_IMAGE_DIR="${BASE_DIR}/apps/skipper/images"

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "ERROR: $1" >&2
	exit ${_ret}
}


# THE DEFAULTS INITIALIZATION
_arg_repository="not-set"
_arg_app="data-flow"


print_help()
{
	printf '%s\n' "Relocate image help"
	printf 'Usage: %s [-r|--repository <arg>] [-a|--app <arg>] [-h|--help]\n' "$0"
	printf '\t%s\n' "-r, --repository: Import images into given image repository (no default)"
	printf '\t%s\n' "-a, --app: Application to relocate, data-flow, composed-task-runner or skipper (default: data-flow)"
	printf '\t%s\n' "-h, --help: Prints help"
}

# The parsing of the command-line
parse_commandline()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			# Since we know that we got the long or short option,
			# we just reach out for the next argument to get the value.
			-r|--repository)
				test $# -lt 2 && _PRINT_HELP=yes die "Missing value for the argument '$_key'." 1
				_arg_repository="$2"
				shift
				;;
			-a|--app)
				test $# -lt 2 && _PRINT_HELP=yes die "Missing value for the argument '$_key'." 1
				_arg_app="$2"
				shift
				;;
			# The help argurment doesn't accept a value,
			# we expect the --help or -h, so we watch for them.
			-h|--help)
				print_help
				exit 0
				;;
			*)
				_PRINT_HELP=yes die "Got an unexpected argument '$1'" 1
				;;
		esac
		shift
	done
}

check_prereq()
{
  if ! [ -x "$(command -v $1)" ]; then
    echo "This script requires '$1' to be installed."
    exit 1
  fi
}

update_kustomization()
{
  app=$1
  name_match=$2
  if ! [ -x "$(command -v yq)" ]; then
    echo "Could not find the 'yq' command; you need to make manual adjustments to the following kustomization scripts:"
    echo " "
    echo " - ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml"
    echo " - ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml"
    echo " "
    echo "Remove the 'newTag' line under 'images:' and update 'newName:' value under 'images:' with the image name shown:"
    if ! [ -x "$(command -v sed)" ]; then
      cat ${BASE_DIR}/apps/${app}/images/${app}-relocated-release.yaml
    else
      image_line=$(sed -n 2p ${BASE_DIR}/apps/${app}/images/${app}-relocated-release.yaml)
      image=${image_line#*image: }
      image_name=${image%@*}
      echo "  ${image_name}"
    fi
    return
  fi
  image=$(yq r ${BASE_DIR}/apps/${app}/images/${app}-relocated-release.yaml image)
  image_name=${image%@*}
  image_digest=${image#*@}
  docker pull ${image}
  echo "Updating ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml"
  dev_name=$(yq r ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml images.name==${name_match}.newName)
  dev_tag=$(yq r ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml images.name==${name_match}.newTag)
  echo "Tagging ${image_name}:${dev_tag}"
  docker tag ${image} ${image_name}:${dev_tag}
  docker push ${image_name}:${dev_tag}
  sed "s|newName: ${dev_name}|newName: ${image_name}|" \
    ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml \
    > ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization-temp.yaml
  rm ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml
  mv ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization-temp.yaml \
    ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/kustomization.yaml
  echo "Updating ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml"
  prod_name=$(yq r ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml images.name==${name_match}.newName)
  prod_tag=$(yq r ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml images.name==${name_match}.newTag)
  echo "Tagging ${image_name}:${prod_tag}"
  docker tag ${image} ${image_name}:${prod_tag}
  docker push ${image_name}:${prod_tag}
  sed "s|newName: ${prod_name}|newName: ${image_name}|" \
    ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml \
    > ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization-temp.yaml
  rm ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml
  mv ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization-temp.yaml \
    ${BASE_DIR}/apps/${app}/kustomize/overlays/production/kustomization.yaml
}

update_application()
{
  app=$1
  if ! [ -x "$(command -v yq)" ]; then
    echo "Could not find the 'yq' command; you need to make manual adjustments to the following application.yaml files:"
    echo " "
    echo " - ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/application.yaml"
    echo " - ${BASE_DIR}/apps/${app}/kustomize/overlays/production/application.yaml"
    echo " "
    echo "Update the '' property with the URL shown:"
    if ! [ -x "$(command -v sed)" ]; then
      cat ${BASE_DIR}/apps/${app}/images/composed-task-runner-relocated-release.yaml
    else
      image_line=$(sed -n 2p ${BASE_DIR}/apps/${app}/images/composed-task-runner-relocated-release.yaml)
      image=${image_line#*image: }
      image_name=${image%@*}
      echo "  ${image_name}"
    fi
    return
  fi
  image=$(yq r ${BASE_DIR}/apps/${app}/images/composed-task-runner-relocated-release.yaml image)
  image_name=${image%@*}
  image_digest=${image#*@}
  docker pull ${image}
  dev_url=$(yq r ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/application.yaml "spring.cloud.dataflow.task.composedtaskrunner.uri")
  dev_image=${dev_url#docker://*}
  dev_name=${dev_image%:*}
  dev_tag=$(yq r ${BASE_DIR}/apps/${app}/images/composed-task-runner-resolved-release.yaml metadata.annotations.[kbld.k14s.io/images] | yq r - .Metas[0].Tag)
  echo "Tagging ${image_name}:${dev_tag}"
  docker tag ${image} ${image_name}:${dev_tag}
  docker push ${image_name}:${dev_tag}
  echo "Updating ${BASE_DIR}/apps/${app}/kustomize/overlays/dev/application.yaml"
  yq w -i "${BASE_DIR}/apps/${app}/kustomize/overlays/dev/application.yaml" "spring.cloud.dataflow.task.composedtaskrunner.uri" "docker://${image}"
  echo "Updating ${BASE_DIR}/apps/${app}/kustomize/overlays/production/application.yaml"
  yq w -i "${BASE_DIR}/apps/${app}/kustomize/overlays/production/application.yaml" "spring.cloud.dataflow.task.composedtaskrunner.uri" "docker://${image}"
}


parse_commandline "$@"

# check_prereqs
check_prereq 'kbld'
check_prereq 'kubectl'

if [ "$_arg_repository" == "not-set" ]; then
    echo -e "--repository argument is required.\n"
    print_help
    exit 1
fi

if [ "$_arg_app" == "data-flow" ]; then
    if [ ! -d "${DATA_FLOW_IMAGE_DIR}" ]; then
      echo -e "The directory ${DATA_FLOW_IMAGE_DIR} was not found."
      exit 1
    fi
    kbld unpkg -f "${DATA_FLOW_IMAGE_DIR}/data-flow-resolved-release.yaml" --input "${DATA_FLOW_IMAGE_DIR}/data-flow-image.tar" --repository "$_arg_repository" > "${DATA_FLOW_IMAGE_DIR}/data-flow-relocated-release.yaml"
    update_kustomization "data-flow" "springcloud/spring-cloud-dataflow-server"
elif [ "$_arg_app" == "composed-task-runner" ]; then
    if [ ! -d "${DATA_FLOW_IMAGE_DIR}" ]; then
      echo -e "The directory ${DATA_FLOW_IMAGE_DIR} was not found."
      exit 1
    fi
    kbld unpkg -f "${DATA_FLOW_IMAGE_DIR}/composed-task-runner-resolved-release.yaml" --input "${DATA_FLOW_IMAGE_DIR}/composed-task-runner-image.tar" --repository "$_arg_repository" > "${DATA_FLOW_IMAGE_DIR}/composed-task-runner-relocated-release.yaml"
    update_application "data-flow" "springcloud/spring-cloud-dataflow-composed-task-runner"
elif [ "$_arg_app" == "skipper" ]; then
    if [ ! -d "${SKIPPER_IMAGE_DIR}" ]; then
      echo -e "The directory ${SKIPPER_IMAGE_DIR} was not found."
      exit 1
    fi
    kbld unpkg -f "${SKIPPER_IMAGE_DIR}/skipper-resolved-release.yaml" --input "${SKIPPER_IMAGE_DIR}/skipper-image.tar" --repository "$_arg_repository" > "${SKIPPER_IMAGE_DIR}/skipper-relocated-release.yaml"
    update_kustomization  "skipper" "springcloud/spring-cloud-skipper-server"
else
    echo -e "Only data-flow, composed-task-runner and skipper supported as an app to relocate.\n"
    print_help
    exit 1
fi
