#!/usr/bin/env bash

kubectl get configmap redis-database-assignment-operator-in-use-dbs-list || kubectl create configmap redis-database-assignment-operator-in-use-dbs-list --from-literal=dbs={}
