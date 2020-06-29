#!/bin/bash

#cp /home/sgxuser/duet-internal/.stack-work/install/x86_64-linux/[insert folder name here]/8.6.3/bin/duet /tmp/
#sh enclave-prep.sh
cd /home/sgxuser/graphene-ra/LibOS/shim/test/native
./pal_loader SGX duet.manifest.sgx run /tmp/query.ed.duet /tmp/epsilon.txt /tmp/delta.txt /tmp/database.csv +RTS -V0

