FROM flant/shell-operator:latest-alpine3.11

RUN apk add --no-cache redis

ADD hooks /hooks
ADD engine /engine
