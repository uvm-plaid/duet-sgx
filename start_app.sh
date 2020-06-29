#!/bin/bash
export FLASK_APP=$HOME/duet-sgx/app.py
cd $HOME/graphene/LibOS/shim/test/native
duet="$PWD/pal_loader SGX $PWD/duet.manifest.sgx"
export GHC_FLAGS="+RTS -V0"
export DUET_PATH=$duet
export EPSILON_BOUND=12.0
echo "1000.0" > /tmp/epsilon.txt
echo "0.0001" > /tmp/delta.txt
python -m flask run

