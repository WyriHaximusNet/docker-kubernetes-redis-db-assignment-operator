# Kuberneter Redis Database Assignment Operator

[![Github Actions](https://github.com/WyriHaximusNet/docker-kubernetes-redis-db-assignment-operator/workflows/Continuous%20Integration/badge.svg)](https://github.com/wyrihaximusnet/docker-kubernetes-redis-db-assignment-operator/actions)
[![Docker hub](https://img.shields.io/badge/Docker%20Hub-00a5c9.svg?logo=docker&style=flat&color=00a5c9&labelColor=00a5c9&logoColor=white)](https://hub.docker.com/r/wyrihaximusnet/kubernetes-redis-db-assignment-operator/)
[![Docker hub](https://img.shields.io/docker/pulls/wyrihaximusnet/kubernetes-redis-db-assignment-operator.svg?color=00a5c9&labelColor=03566a)](https://hub.docker.com/r/wyrihaximusnet/kubernetes-redis-db-assignment-operator/)
[![Docker hub](https://img.shields.io/microbadger/image-size/wyrihaximusnet/kubernetes-redis-db-assignment-operator/7.4-zts-alpine3.12.svg?color=00a5c9&labelColor=03566a)](https://hub.docker.com/r/wyrihaximusnet/kubernetes-redis-db-assignment-operator/)

## Usage

Suggested usage is to use [`Helm`](https://hub.helm.sh/charts/wyrihaximusnet/redis-db-assignment-operator) to install this operator:

```bash
helm repo add WyriHaximusNet https://helm.wyrihaximus.net/
helm repo update
helm upgrade redis-db-assignment-operator WyriHaximusNet/redis-db-assignment-operator --install --wait --atomic --namespace=redis
```

After the Helm install following definition will create a redis-database resource on your cluster. The operator picks 
it up and finds a redis database that isn't in use according to the operators internal state.

```yaml
apiVersion: wyrihaximus.net/v1
kind: RedisDatabase
metadata:
  name: example
spec:
  secret:
    name: example-redis-database
  service:
    read: redis://redis-follower.redis.svc.cluster.local:6379/
    write: redis://redis-leader.redis.svc.cluster.local:6379/
```

The resulting secret looks like this:

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: example-redis-database
  namespace: default
data:
  DATABASE: BASE64_ENCODED
  READ: BASE64_ENCODED
  WRITE: BASE64_ENCODED
```
