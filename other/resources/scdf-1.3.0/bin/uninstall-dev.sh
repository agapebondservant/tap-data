#!/usr/bin/env bash

set -euo pipefail

check_prereq()
{
  if ! [ -x "$(command -v $1)" ]; then
    echo "This script requires '$1' to be installed."
    exit 1
  fi
}

check_prereq 'kapp'

app_list=$(kapp list --column name | grep "data-flow\|skipper" || true)
if [[ $app_list > "" ]]; then
  apps=($app_list)
  echo "Unistalling apps: ${apps[@]}"
  for i in ${!apps[@]}; do
    kapp delete -y -a ${apps[$i]}
  done
else
  echo "No apps to unistall"
fi

svc_list=$(kapp list --column name | grep "mysql\|postgresql\|rabbitmq\|kafka\|monitoring-proxy\|monitoring" || true)
if [[ $svc_list > "" ]]; then
  svcs=($svc_list)
  echo "Unistalling services: ${svcs[@]}"
  for i in ${!svcs[@]}; do
    kapp delete -y --apply-ignored -a ${svcs[$i]}
  done
else
  echo "No services to unistall"
fi
