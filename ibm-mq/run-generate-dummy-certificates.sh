#!/bin/bash

set -xe

SYSTEM_UID=$(id -u)
SYSTEM_GID=$(id -g)

rm -f java-client-certificates-and-keys/*.jks

docker run --rm -u "${SYSTEM_UID}:${SYSTEM_GID}" -v "$PWD":/scripts -w /scripts/mqm-key-repository --entrypoint /bin/bash ibmcom/mq:9 generate-dummy-certificates.sh

keytool -import -alias mqserver -file ./mqm-key-repository/mqserver.crt -keystore ./mqm-key-repository/message-consumer-truststore.jks -storepass changeit -noprompt
keytool -import -alias mqserver -file ./mqm-key-repository/mqserver.crt -keystore ./mqm-key-repository/message-producer-truststore.jks -storepass changeit -noprompt

mv mqm-key-repository/*.jks java-client-certificates-and-keys

rm -f mqm-key-repository/*.crt
