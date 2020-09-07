FROM flant/shell-operator:latest-alpine3.12

RUN apk add --no-cache redis

ADD hooks /hooks
ADD engine /engine
