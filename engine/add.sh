#!/usr/bin/env bash

#
# Taken from: https://wp.vpalos.com/537/uri-parsing-using-bash-built-in-features/
#

#
# URI parsing function
#
# The function creates global variables with the parsed results.
# It returns 0 if parsing was successful or non-zero otherwise.
#
# [schema://][user[:password]@]host[:port][/path][?[arg1=val1]...][#fragment]
#
function uri_parser() {
    # uri capture
    uri="$@"

    # safe escaping
    uri="${uri//\`/%60}"
    uri="${uri//\"/%22}"

    # top level parsing
    pattern='^(([a-z]{3,5})://)?((([^:\/]+)(:([^@\/]*))?@)?([^:\/?]+)(:([0-9]+))?)(\/[^?]*)?(\?[^#]*)?(#.*)?$'
    [[ "$uri" =~ $pattern ]] || return 1;

    # component extraction
    uri=${BASH_REMATCH[0]}
    uri_schema=${BASH_REMATCH[2]}
    uri_address=${BASH_REMATCH[3]}
    uri_user=${BASH_REMATCH[5]}
    uri_password=${BASH_REMATCH[7]}
    uri_host=${BASH_REMATCH[8]}
    uri_port=${BASH_REMATCH[10]}
    uri_path=${BASH_REMATCH[11]}
    uri_query=${BASH_REMATCH[12]}
    uri_fragment=${BASH_REMATCH[13]}

    # path parsing
    count=0
    path="$uri_path"
    pattern='^/+([^/]+)'
    while [[ $path =~ $pattern ]]; do
        eval "uri_parts[$count]=\"${BASH_REMATCH[1]}\""
        path="${path:${#BASH_REMATCH[0]}}"
        let count++
    done

    # query parsing
    count=0
    query="$uri_query"
    pattern='^[?&]+([^= ]+)(=([^&]*))?'
    while [[ $query =~ $pattern ]]; do
        eval "uri_args[$count]=\"${BASH_REMATCH[1]}\""
        eval "uri_arg_${BASH_REMATCH[1]}=\"${BASH_REMATCH[3]}\""
        query="${query:${#BASH_REMATCH[0]}}"
        let count++
    done

    # return success
    return 0
}

json=$(echo "$1")
name=$(echo "$json" | jq -r '.metadata.name')
namespace=$(echo "$json" | jq -r '.metadata.namespace')
kind=$(echo "$json" | jq -r '.kind')
secret=$(echo "$json" | jq -r '.spec.secret.name')
read=$(echo "$json" | jq -r '.spec.service.read')
write=$(echo "$json" | jq -r '.spec.service.write')

uri_parser "${write}" || { echo "Malformed URI! ${write}"; exit 1; }
uri_host_port="${uri_host}:${uri_port}"
write_dsn="${uri_schema}://${uri_address}/"
uri_parser "${read}" || { echo "Malformed URI! ${read}"; exit 1; }
read_dsn="${uri_schema}://${uri_address}/"

echo "${namespace}/${name} object is added"
echo "${namespace}/${secret} is target secret"
echo "${read} is read service"
echo "${write} is write service"

(kubectl get secret -n "${namespace}" "${secret}")
if [[ "$?" == "1" ]] ; then
  maxDatabases=$(redis-cli -u "${write}" CONFIG GET databases | grep -v databases)
  redisServerIsKnown=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r -c '.data.dbs' | jq -r ".\"${uri_host_port}\"" | wc -l)
  if [[ "$redisServerIsKnown" == "1" ]] ; then
      kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq -r ". * {\"${uri_host_port}\": {}}" | jq -c) --dry-run -o yaml | kubectl apply -f -
      for i in $(seq 0 $maxDatabases);
      do
          kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq -r ". * {\"${uri_host_port}\": {\"db${i}\": \"free\"}}" | jq -c) --dry-run -o yaml | kubectl apply -f -
      done
  fi

  echo "Secret ${namespace}/${secret} doesn't exist"

  for i in $(seq 0 $maxDatabases);
  do
      isDatabaseFree=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq ".[\"${uri_host_port}\"].db${i}" | grep free | wc -l)
      if [[ "$isDatabaseFree" == "1" ]] ; then
        isDatabaseEmpty=$(redis-cli -u "${write}" INFO keyspace | grep -v Keyspace | grep "db${i}" | wc -l)
        if [[ "$isDatabaseEmpty" == "0" ]] ; then
          echo "Database ${i} is available"
          kubectl create secret generic "${secret}" -n "${namespace}" --from-literal=DATABASE="${i}" --from-literal=READ="${read_dsn}${i}" --from-literal=WRITE="${write_dsn}${i}"
          kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs=$(kubectl get configmap redis-database-assignment-operator-in-use-dbs-list -o json | jq -r '.data.dbs' | jq -r ". * {\"${uri_host_port}\": {\"db${i}\": \"${namespace}/${secret}\"}}" | jq -c) --dry-run -o yaml | kubectl apply -f -
          echo "Database ${i} has now been claimed"
          break
        fi
      fi
  done
else
  echo "Secret ${namespace}/${secret} exists, no need to do anything"
fi
