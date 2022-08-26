#!/bin/bash

# populate interpolated variables
echo "Preparing environment..."
[ ! -z "$1" ] && ENV_FILE=$1 || ENV_FILE=.env
source "$ENV_FILE"
for orig in `find $(pwd) -name "*.in.*" -type f`; do
  target=$(echo $orig | sed 's/\.in//')
  envsubst < $orig > $target
  grep -qxF $target .gitignore || echo $target >> .gitignore
  git rm --cached -q $target > /dev/null 2>&1
done
echo "Environment variables updated."