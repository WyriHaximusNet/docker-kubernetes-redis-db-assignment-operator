FROM flant/shell-operator:v1.0.0-rc.1

RUN apk add --no-cache redis

ADD hooks /hooks
ADD engine /engine
