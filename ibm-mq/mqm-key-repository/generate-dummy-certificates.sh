#!/bin/bash

set -xe

# Cleanup
rm -f *.kdb *.rdb *.sth *.crt *.jks

# Create self-signed certificates for the queue manager:
runmqckm -keydb -create -db key -pw changeit -type cms -stash
runmqckm -cert -create -db key.kdb -pw changeit -label mqserver -dn "CN=mqserver,O=MyOrg,C=US" -size 2048 -sig_alg SHA256withRSA -expire 3650

# Create self-signed certificates for the clients - message producer and consumer:
runmqckm -keydb -create -db message-consumer -pw changeit -type cms -stash
runmqckm -cert -create -db message-consumer.kdb -pw changeit -label message-consumer -dn "CN=message-consumer,O=MyOrg,C=US" -size 2048 -sig_alg SHA256withRSA -expire 3650
runmqckm -keydb -create -db message-producer -pw changeit -type cms -stash
runmqckm -cert -create -db message-producer.kdb -pw changeit -label message-producer -dn "CN=message-producer,O=MyOrg,C=US" -size 2048 -sig_alg SHA256withRSA -expire 3650

# Extract the certificates to files:
runmqckm -cert -extract -db key.kdb -pw changeit -label mqserver -target mqserver.crt -format ascii
runmqckm -cert -extract -db message-consumer.kdb -pw changeit -label message-consumer -target message-consumer.crt -format ascii
runmqckm -cert -extract -db message-producer.kdb -pw changeit -label message-producer -target message-producer.crt -format ascii

# Import client certificates into the queue manager truststore:
runmqckm -keydb -create -db trust.kdb -pw changeit -type cms -stash
runmqckm -cert -add -db trust.kdb -pw changeit -label message-consumer -file message-consumer.crt -format ascii
runmqckm -cert -add -db trust.kdb -pw changeit -label message-producer -file message-producer.crt -format ascii

runmqckm -cert -add -db key.kdb -pw changeit -label message-consumer -file message-consumer.crt -format ascii
runmqckm -cert -add -db key.kdb -pw changeit -label message-producer -file message-producer.crt -format ascii

# Extract private key and certificate to a Java keystore for the clients:
runmqckm -cert -export -db message-consumer.kdb -pw changeit -label message-consumer -target message-consumer-keystore.jks -target_pw changeit -target_type jks
runmqckm -cert -export -db message-producer.kdb -pw changeit -label message-producer -target message-producer-keystore.jks -target_pw changeit -target_type jks

# Cleanup
rm -f message-*.*db message-*.sth

chmod 0644 *.kdb *.rdb *.sth
