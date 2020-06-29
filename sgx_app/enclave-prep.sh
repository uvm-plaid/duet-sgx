#!/bin/bash

cd ~/graphene/Pal/src/host/Linux-SGX/

./signer/pal-sgx-sign -key signer/enclave-key.pem -libpal libpal.so -exec /tmp/duet -manifest ~/graphene/LibOS/shim/test/native/duet.manifest.template -output duet.manifest.sgx

./signer/pal-sgx-get-token -sig duet.sig -output duet.token

cp duet.* ~/graphene/LibOS/shim/test/native/
