#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && cd .. && pwd)"
SERVICES_DIR="${BASE_DIR}/services/dev"

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "ERROR: $1" >&2
	exit ${_ret}
}


# THE DEFAULTS INITIALIZATION
_arg_database="postgresql"
_arg_broker="rabbitmq"
_arg_monitoring="none"
_arg_output_dir=""


print_help()
{
	printf '%s\n' "Install for development help"
	printf 'Usage: %s [-d|--database <arg>] [-b|--broker <arg>] [-h|--help]\n' "$0"
	printf '\t%s\n' "-d, --database: The database to use -- postgresql (default) or mysql"
	printf '\t%s\n' "-b, --broker: The message broker to use -- rabbitmq (default) or kafka"
	printf '\t%s\n' "-m, --monitoring: The monitoring solution to install and enable -- none (default) or prometheus"
	printf '\t%s\n' "-o, --output-dir: The output directory for writing the config files that can be applied later"
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
			-d|--database)
				test $# -lt 2 && _PRINT_HELP=yes die "Missing value for the argument '$_key'." 1
				test "$2" != "postgresql" -a "$2" != "mysql" && _PRINT_HELP=yes die "Invalid value '$2' for the argument '$_key'." 1
				_arg_database="$2"
				shift
				;;
			-b|--broker)
				test $# -lt 2 && _PRINT_HELP=yes die "Missing value for the argument '$_key'." 1
				test "$2" != "rabbitmq" -a "$2" != "kafka" && _PRINT_HELP=yes die "Invalid value '$2' for the argument '$_key'." 1
				_arg_broker="$2"
				shift
				;;
			-m|--monitoring)
				test $# -lt 2 && _PRINT_HELP=yes die "Missing value for the argument '$_key'." 1
				test "$2" != "none" -a "$2" != "prometheus" && _PRINT_HELP=yes die "Invalid value '$2' for the argument '$_key'." 1
				_arg_monitoring="$2"
				shift
				;;
			-o|--output-dir)
				test $# -lt 2 && _PRINT_HELP=yes die "Missing value for the argument '$_key'." 1
				_arg_output_dir="$2"
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

wait_for_statefuleset()
{
  r="0"
  echo -n "Waiting for $1 service to become READY "
  while [[ "$r" < "1" ]]; do
    rr=$(kubectl get statefulset $1 -ojsonpath={.status.readyReplicas})
    if [[ "$rr" > "" ]]; then
      r="$rr"
    else
      echo -n "."
      sleep 2
    fi
  done
  echo ""
}

parse_commandline "$@"

echo "Configuring SCDF for K8s to use $_arg_database and $_arg_broker"
if [[ $_arg_monitoring == "prometheus" ]]; then
  echo "Enabling monitoring with $_arg_monitoring"
fi

check_prereq 'kapp'
check_prereq 'kubectl'

if [[ "$_arg_output_dir" > "" ]]; then
	if [ -d "$_arg_output_dir" ]; then
    if [[ -f "$_arg_output_dir/data-flow.yaml" || -f "$_arg_output_dir/skipper.yaml" ]]; then
      echo "Output directory $_arg_output_dir already contains configuration files, please specify a different directory name"
      exit 1
    fi
	fi
  mkdir -p $_arg_output_dir
  echo ""
  echo "Writing configuration files to $_arg_output_dir"
else
  kapp -y deploy -a $_arg_database -f "${SERVICES_DIR}/$_arg_database/"
  kapp -y deploy -a $_arg_broker -f "${SERVICES_DIR}/$_arg_broker/"
  if [[ $_arg_database == "mysql" ]]; then
    wait_for_statefuleset $_arg_database-master
  else
    wait_for_statefuleset $_arg_database
  fi
  wait_for_statefuleset $_arg_broker
  if [[ $_arg_monitoring == "prometheus" ]]; then
    kapp -y deploy -a monitoring -f "${SERVICES_DIR}/monitoring/"
  fi
fi

if [[ $_arg_database == "mysql" ]]; then
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-mysql.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-database.yaml"
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-mysql-patch.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-database-patch.yaml"
  cp "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/application-mysql.yaml" "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/application-database.yaml"
  cp "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-mysql-patch.yaml" "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-database-patch.yaml"
fi
if [[ $_arg_database == "postgresql" ]]; then
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-postgresql.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-database.yaml"
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-postgresql-patch.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-database-patch.yaml"
  cp "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/application-postgresql.yaml" "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/application-database.yaml"
  cp "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-postgresql-patch.yaml" "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-database-patch.yaml"
fi
if [[ $_arg_broker == "rabbitmq" ]]; then
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-rabbitmq.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-broker.yaml"
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-rabbitmq-patch.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-broker-patch.yaml"
fi
if [[ $_arg_broker == "kafka" ]]; then
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-kafka.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/application-broker.yaml"
  cp "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-kafka-patch.yaml" "${BASE_DIR}/apps/skipper/kustomize/overlays/dev/deployment-broker-patch.yaml"
fi
if [[ $_arg_monitoring == "none" ]]; then
  cp "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-patch-no-monitoring.yaml" "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-patch.yaml"
else
  cp "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-patch-monitoring.yaml" "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev/deployment-patch.yaml"
fi

if [[ "$_arg_output_dir" == "" ]]; then
  kubectl kustomize "${BASE_DIR}/apps/skipper/kustomize/overlays/dev" | kapp -y deploy -a skipper -f -
  kubectl kustomize "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev" | kapp -y deploy -a data-flow -f -
  if [[ $_arg_monitoring == "prometheus" ]]; then
    kapp -y deploy -a monitoring-proxy -f "${SERVICES_DIR}/monitoring-proxy/"
  fi
  echo "To uninstall run ./bin/uninstall-dev.sh"
else
  kubectl kustomize "${BASE_DIR}/apps/skipper/kustomize/overlays/dev" > $_arg_output_dir/skipper.yaml
  kubectl kustomize "${BASE_DIR}/apps/data-flow/kustomize/overlays/dev" > $_arg_output_dir/data-flow.yaml
  if [[ $_arg_database == "mysql" ]]; then
    db_statefuleset=$_arg_database-master
  else
    db_statefuleset=$_arg_database
  fi
  cat <<EOF

To deploy the Spring Cloud Data Flow system using kubectl, you can run the following.

  Change to this directory:
    cd $PWD

  To deploy database service run:
    kubectl apply -f ./services/dev/$_arg_database
    kubectl wait pod/$db_statefuleset-0 --for=condition=Ready

  To deploy broker service run:
    kubectl apply -f ./services/dev/$_arg_broker
    kubectl wait pod/$_arg_broker-0 --for=condition=Ready
EOF
  if [[ $_arg_monitoring == "prometheus" ]]; then
    cat <<EOF

  To deploy monitoring system run:
    kubectl apply -f ./services/dev/monitoring
EOF
  fi
  cat <<EOF

  To deploy Skipper server run:  
    kubectl apply -f $_arg_output_dir/skipper.yaml
    kubectl wait pod -l=app=skipper --for=condition=Ready

  To deploy Data Flow server run:  
    kubectl apply -f $_arg_output_dir/data-flow.yaml
    kubectl wait pod -l=app=scdf-server --for=condition=Ready

EOF
  if [[ $_arg_monitoring == "prometheus" ]]; then
    cat <<EOF
  To deploy monitoring proxy run:
    kubectl apply -f ./services/dev/monitoring-proxy

EOF
  fi
fi

