#!/usr/bin/env bash

if [[ $1 == "--config" ]] ; then
  cat <<EOF
{
  "configVersion":"v1",
  "kubernetes":[{
    "apiVersion": "wyrihaximus.net/v1",
    "kind": "RedisDatabase",
    "executeHookOnEvent":["Added"]
  }]
}
EOF
else
  type=$(jq -r '.[0].type' ${BINDING_CONTEXT_PATH})
  echo "Event: ${type}"
  if [[ $type == "Event" ]] ; then
    while IFS= read -r object; do
      /engine/add.sh "$object"
    done< <(jq -c '.[].object' < ${BINDING_CONTEXT_PATH})
  fi
fi
