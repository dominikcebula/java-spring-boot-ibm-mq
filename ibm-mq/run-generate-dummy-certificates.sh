#!/bin/bash

GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
NC="\033[0m"
CHECK="✔️"
CROSS="❌"
INFO="ℹ️"

WRKDIR="$(dirname "$0")/wrkdir"
PASSWORD="changeit"

function info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

function success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

function error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

function prepare_wrkdir() {
    info "Creating temporary working directory at $WRKDIR"
    rm -rf "$WRKDIR"
    mkdir -p "$WRKDIR" || { error "Error occurred while creating working directory"; exit 1; }
    success "Working directory created"
}

function generate_root_ca() {
    info "Generating Root CA private key and certificate"
    openssl genrsa -out "$WRKDIR/rootCA.key" 4096 || { error "Error occurred while generating Root CA private key"; exit 1; }
    openssl req -x509 -new -nodes -key "$WRKDIR/rootCA.key" -sha256 -days 3650 -out "$WRKDIR/rootCA.crt" -subj "/C=PL/ST=Test/L=Test/O=Test/OU=RootCA/CN=RootCA" || { error "Error occurred while generating Root CA certificate"; exit 1; }
    success "Root CA generated"
}

function generate_intermediate_ca() {
    info "Generating Intermediate CA private key and CSR"
    openssl genrsa -out "$WRKDIR/intermediateCA.key" 4096 || { error "Error occurred while generating Intermediate CA private key"; exit 1; }
    openssl req -new -key "$WRKDIR/intermediateCA.key" -out "$WRKDIR/intermediateCA.csr" -subj "/C=PL/ST=Test/L=Test/O=Test/OU=IntermediateCA/CN=IntermediateCA" || { error "Error occurred while generating Intermediate CA CSR"; exit 1; }
    info "Signing Intermediate CA CSR with Root CA"
    openssl x509 -req -in "$WRKDIR/intermediateCA.csr" -CA "$WRKDIR/rootCA.crt" -CAkey "$WRKDIR/rootCA.key" -CAcreateserial -out "$WRKDIR/intermediateCA.crt" -days 1825 -sha256 || { error "Error occurred while signing Intermediate CA"; exit 1; }
    success "Intermediate CA generated and signed by Root CA"
}

function generate_signed_cert() {
    local NAME=$1
    local CN=$2
    info "Generating private key and CSR for $NAME"
    openssl genrsa -out "$WRKDIR/${NAME}.key" 2048 || { error "Error occurred while generating $NAME private key"; exit 1; }
    openssl req -new -key "$WRKDIR/${NAME}.key" -out "$WRKDIR/${NAME}.csr" -subj "/C=PL/ST=Test/L=Test/O=Test/OU=$NAME/CN=$CN" || { error "Error occurred while generating $NAME CSR"; exit 1; }
    info "Signing $NAME CSR with Intermediate CA"
    openssl x509 -req -in "$WRKDIR/${NAME}.csr" -CA "$WRKDIR/intermediateCA.crt" -CAkey "$WRKDIR/intermediateCA.key" -CAcreateserial -out "$WRKDIR/${NAME}.crt" -days 825 -sha256 || { error "Error occurred while signing $NAME certificate"; exit 1; }
    success "$NAME certificate and private key generated and signed by Intermediate CA"
}

function generate_pkcs12_keystore() {
    local NAME=$1
    local PFX=$2
    info "Generating PKCS#12 keystore for $NAME"
    cat "$WRKDIR/${NAME}.crt" "$WRKDIR/intermediateCA.crt" "$WRKDIR/rootCA.crt" > "$WRKDIR/${NAME}-fullchain.crt"
    openssl pkcs12 -export -out "$WRKDIR/$PFX" -inkey "$WRKDIR/${NAME}.key" -in "$WRKDIR/${NAME}-fullchain.crt" -password pass:$PASSWORD || { error "Error occurred while generating $NAME keystore"; exit 1; }
    success "$NAME keystore ($PFX) generated"
}

function generate_pkcs12_truststore() {
    local PFX=$1
    info "Generating PKCS#12 truststore ($PFX) with Root and Intermediate CA using keytool"
    local TRUSTSTORE_PATH="$WRKDIR/$PFX"
    local ALIAS_ROOT="rootca"
    local ALIAS_INTERMEDIATE="intermediateca"
    # Remove existing truststore if present
    rm -f "$TRUSTSTORE_PATH"
    # Import Root CA
    keytool -importcert -noprompt -trustcacerts -alias "$ALIAS_ROOT" -file "$WRKDIR/rootCA.crt" -keystore "$TRUSTSTORE_PATH" -storetype PKCS12 -storepass "$PASSWORD" || { error "Error importing Root CA into truststore $PFX"; exit 1; }
    # Import Intermediate CA
    keytool -importcert -noprompt -trustcacerts -alias "$ALIAS_INTERMEDIATE" -file "$WRKDIR/intermediateCA.crt" -keystore "$TRUSTSTORE_PATH" -storetype PKCS12 -storepass "$PASSWORD" || { error "Error importing Intermediate CA into truststore $PFX"; exit 1; }
    success "Truststore ($PFX) generated using keytool"
}

function copy_keystores_to_target() {
    info "Copying keystores and truststores to target locations"
    cp "$WRKDIR/message-consumer-keystore.pfx" "$(dirname "$0")/java-client-certificates-and-keys/message-consumer-keystore.pfx" || { error "Error copying message-consumer-keystore"; exit 1; }
    cp "$WRKDIR/message-consumer-truststore.pfx" "$(dirname "$0")/java-client-certificates-and-keys/message-consumer-truststore.pfx" || { error "Error copying message-consumer-truststore"; exit 1; }
    cp "$WRKDIR/message-producer-keystore.pfx" "$(dirname "$0")/java-client-certificates-and-keys/message-producer-keystore.pfx" || { error "Error copying message-producer-keystore"; exit 1; }
    cp "$WRKDIR/message-producer-truststore.pfx" "$(dirname "$0")/java-client-certificates-and-keys/message-producer-truststore.pfx" || { error "Error copying message-producer-truststore"; exit 1; }
    success "Keystores and truststores copied"
}

function copy_certificates_and_keys_to_mqm_pki() {
    info "Copying certificates and keys to mqm-pki structure"
    local BASE_DIR
    BASE_DIR="$(dirname "$0")/mqm-pki"
    local TRUST_DIR="$BASE_DIR/trust"
    local KEYS_DIR="$BASE_DIR/keys/mqserver"

    mkdir -p "$TRUST_DIR" || { error "Error creating trust directory"; exit 1; }
    mkdir -p "$KEYS_DIR" || { error "Error creating keys directory"; exit 1; }
    mkdir -p "$TRUST_DIR/0" || { error "Error creating keys directory with 0 idx"; exit 1; }
    mkdir -p "$TRUST_DIR/1" || { error "Error creating keys directory with 1 idx"; exit 1; }

    cp "$WRKDIR/rootCA.crt" "$TRUST_DIR/0" || { error "Error copying rootCA.crt to trust/0"; exit 1; }
    cp "$WRKDIR/intermediateCA.crt" "$TRUST_DIR/1" || { error "Error copying intermediateCA.crt to trust/1"; exit 1; }
    cp "$WRKDIR/mqserver.key" "$KEYS_DIR/mqserver.key" || { error "Error copying mqserver.key"; exit 1; }
    cp "$WRKDIR/mqserver.crt" "$KEYS_DIR/mqserver.crt" || { error "Error copying mqserver.crt"; exit 1; }

    success "Certificates and keys copied to mqm-pki structure"
}

function set_permissions() {
    local DIR=$1
    local MODE=$2
    info "Setting permissions for $DIR to $MODE"
    chmod -R "$MODE" "$DIR" || { error "Error setting permissions for $DIR"; exit 1; }
    success "Permissions for $DIR set to $MODE"
}

function cleanup() {
    info "Cleaning up working directory"
    rm -rf "$WRKDIR" || { error "Error occurred while cleaning up working directory"; exit 1; }
    success "Working directory cleaned up"
}

function main() {
    prepare_wrkdir

    generate_root_ca
    generate_intermediate_ca

    generate_signed_cert "mqserver" "mqserver"
    generate_signed_cert "message-consumer" "message-consumer"
    generate_signed_cert "message-producer" "message-producer"

    generate_pkcs12_keystore "message-consumer" "message-consumer-keystore.pfx"
    generate_pkcs12_truststore "message-consumer-truststore.pfx"
    generate_pkcs12_keystore "message-producer" "message-producer-keystore.pfx"
    generate_pkcs12_truststore "message-producer-truststore.pfx"

    copy_keystores_to_target
    copy_certificates_and_keys_to_mqm_pki

    set_permissions "$(dirname "$0")/java-client-certificates-and-keys" 0755
    set_permissions "$(dirname "$0")/mqm-pki" 0755

    cleanup

    success "All operations completed successfully."
}

main
