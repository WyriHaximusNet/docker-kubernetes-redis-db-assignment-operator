FROM flant/shell-operator:v1.0.12

RUN apk add --no-cache redis

ADD hooks /hooks
ADD engine /engine
