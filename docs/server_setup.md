# Setting Up a DuetSGX Server

# Prerequisites

### 0. Install Dependencies
```shell
sudo apt-get install build-essential ocaml automake autoconf libtool wget python \
     gawk bison python-protobuf libssl-dev libcurl4-openssl-dev libprotobuf-dev python3
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" && sudo python3 get-pip.py
sudo pip3 install protobuf
```
### 1. Linux SGX:
``` shell
git clone https://github.com/intel/linux-sgx
cd linux-sgx
make
cd linux/installer/bin
./sgx_linux_x64_sdk_${version}.bin
cd ../deb
sudo dpkg -i ./libsgx-urts_${version}-${revision}_amd64.deb \
     ./libsgx-enclave-common_${version}-${revision}_amd64.deb
sudo service aesmd start
```

### 2. Linux SGX Driver
``` shell
cd ~
git clone -b sgx2 https://github.com/intel/linux-sgx-driver
sudo apt-get install linux-headers-$(uname -r)
make
sudo mkdir -p "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
sudo cp isgx.ko "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
sudo sh -c "cat /etc/modules | grep -Fxq isgx || echo isgx >> /etc/modules"
sudo /sbin/depmod
sudo /sbin/modprobe isgx
```

### 3. Graphene-SGX:
``` shell
cd ~/
git clone https://github.com/oscarlab/graphene
git checkout b3cffe4 # this is the last tested version
cp ~/duet-sgx/sgx_app/duet.manifest.template graphene/LibOS/shim/test/native
cd graphene
git apply ~/duet-sgx/sgx_app/graphene_simple-ra.diff
git submodule update --init -- Pal/src/host/Linux-SGX/sgx-driver/
cd /Pal/src/host/Linux-SGX/signer
openssl genrsa -3 -out enclave-key.pem 3072
cd ../sgx-driver
make (the console will ask for the path of driver, give it: ~/linux-sgx-driver)
cd ~/graphene && make
cd ~/graphene/LibOS/shim/test/native && make SGX=1
```

### 4. Haskell GHC
``` shell
sudo add-apt-repository ppa:hvr/ghc
sudo apt-get update
sudo apt install ghc-8.6.3
```

# Setup

Install Haskell Tool Stack by following preferred method:
https://docs.haskellstack.org/en/stable/install_and_upgrade/

Then, build the Duet binary, and keep track of where it's stored:

``` shell
cd backend
stack build
```

The output of Stack will include a message like the following:


``` shell
Installing executable duet in /home/jnear/co/code/duet-hs/.stack-work/install/x86_64-linux/715383cb8403832690ae3cd7ad7281e17ced8225f7dd2bff8221ceb57a100d6d/8.6.3/bin
```

Set up your Duet path by setting the environment variable `DUET_PATH`
to the path Stack spits out plus `duet`. For example:

``` shell
export DUET_PATH=/home/jnear/co/code/duet-hs/.stack-work/install/x86_64-linux/715383cb8403832690ae3cd7ad7281e17ced8225f7dd2bff8221ceb57a100d6d/8.6.3/bin/duet
```

# Setting the Privacy Budget

The privacy budget is initialized by writing values to two files in `/tmp`:

- The ε parameter is read from the file `/tmp/epsilon.txt`
- The δ parameter is read from the file `/tmp/delta.txt`

For example, the following sets the total privacy budget to ε=1.0, δ=1e-5:

```
echo "1.0" > /tmp/epsilon.txt
echo "0.000001" > /tmp/delta.txt
```

When the DuetSGX server starts, it sets the initial privacy budget to
the values found in these files.

# Running the Server (without SGX)

The server is implemented as a Flask app. To start the server, make
sure your `DUET_PATH` is set, then run the following command:

``` shell
export DUET_PATH=/path/to/duet/binary ; python -m flask run
```

# Running the Server (with SGX)
A set of scripts is provided to help configure and launch Graphene. These require the binary located at $DUET_PATH to be copied to the /tmp folder.
``` shell
sgx_app/enclave_prep.sh
./start_app.sh
```
