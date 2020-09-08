#!/usr/bin/env bash

json=$(echo "$1")
name=$(echo "$json" | jq -r '.metadata.name')
namespace=$(echo "$json" | jq -r '.metadata.namespace')
kind=$(echo "$json" | jq -r '.kind')
secret=$(echo "$json" | jq -r '.spec.secret.name')
read=$(echo "$json" | jq -r '.spec.service.read')
write=$(echo "$json" | jq -r '.spec.service.write')
echo "${namespace}/${name} object is added"
echo "${namespace}/${secret} is target secret"
echo "${read} is read service"
echo "${write} is write service"

(kubectl get secret -n "${namespace}" "${secret}")
if [[ "$?" == "1" ]] ; then
  maxDatabases=$(redis-cli -u "${write}" CONFIG GET databases | grep -v databases)
  redisServerIsKnown=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r -c '.data.dbs' | jq -r ".\"${write}\"" | wc -l)
  if [[ "$redisServerIsKnown" == "1" ]] ; then
      kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq -r ". * {\"${write}\": {}}" | jq -c) --dry-run -o yaml | kubectl apply -f -
      for i in $(seq 0 $maxDatabases);
      do
          kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq -r ". * {\"${write}\": {\"db${i}\": \"free\"}}" | jq -c) --dry-run -o yaml | kubectl apply -f -
      done
  fi

  echo "Secret ${namespace}/${secret} doesn't exist"

  for i in $(seq 0 $maxDatabases);
  do
      isDatabaseFree=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq ".[\"${write}\"].db${i}" | grep free | wc -l)
      if [[ "$isDatabaseFree" == "1" ]] ; then
        echo "Database ${i} is available"
        kubectl create secret generic "${secret}" -n "${namespace}" --from-literal=database="${i}" --from-literal=read="${read}${i}" --from-literal=write="${write}${i}"
        kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq -r ". * {\"${write}\": {\"db${i}\": \"${namespace}/${secret}\"}}" | jq -c) --dry-run -o yaml | kubectl apply -f -
        echo "Database ${i} has now been claimed"
        break
      fi
  done
else
  echo "Secret ${namespace}/${secret} exists, no need to do anything"
fi
