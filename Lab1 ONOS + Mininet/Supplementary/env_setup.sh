#!/bin/bash

YELLOW='\033[1;33m'
NC='\033[0m'

BAZEL=0.27.0

set -e
cd ~
sudo apt update -y

# Install Bazel 0.27.0
if [ ! -f ~/bin/bazel ]; then
    echo -e "${YELLOW}[*] Begin to install Bazel...${NC}"
    sudo apt-get install pkg-config zip g++ zlib1g-dev unzip python3 -y
    wget https://github.com/bazelbuild/bazel/releases/download/${BAZEL}/bazel-${BAZEL}-installer-linux-x86_64.sh
    chmod +x bazel-${BAZEL}-installer-linux-x86_64.sh
    ./bazel-${BAZEL}-installer-linux-x86_64.sh --user
    export PATH="$PATH:$HOME/bin"
    echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bashrc
fi

# Install ONOS 2.2.0
if [ -z "$ONOS_ROOT" ]; then
    echo -e "${YELLOW}[*] Begin to install ONOS...${NC}"
    if [ ! -d ~/onos ]; then
        sudo apt-get install git curl python bzip2 -y
        git clone https://github.com/opennetworkinglab/onos.git
    fi
    cd onos
    git checkout 2.2.0
	# replace http://repo1.maven.org/ to https://repo1.maven.org/ (if exists)
    grep -lr http://repo1.maven.org/ . | xargs -r sed -i 's/http:\/\/repo1\.maven\.org/https:\/\/repo1\.maven\.org/g'

    # if command exits with non-zero status, then not exit immediately
    set +e
    bazel build onos
	# if error occurs when building onos, then maybe some package repository urls are wrong
    if [ "$?" -ne 0 ]; then
        set -e
        find ~/.cache -path "*/external/io_grpc_grpc_java/repositories.bzl" | xargs -r sed -i 's/http:\/\/central\.maven\.org/https:\/\/repo1\.maven\.org/g'
        bazel build onos
    fi
    set -e
    export ONOS_ROOT=~/onos
    echo 'export ONOS_ROOT=~/onos' >> ~/.bashrc
    echo 'source $ONOS_ROOT/tools/dev/bash_profile' >> ~/.bashrc
fi

# Install mininet
if [ -z "$(which mn)" ]; then
    cd ~
    echo -e "${YELLOW}[*] Begin to install mininet...${NC}"
    git clone git://github.com/mininet/mininet
    mininet/util/install.sh -n
fi

# Install OvS 2.11.4
if [ -z "$(which ovs-vsctl)" ]; then
    cd ~
    sudo apt install gcc make
    wget https://www.openvswitch.org/releases/openvswitch-2.11.4.tar.gz
    tar zxf openvswitch-2.11.4.tar.gz
    cd openvswitch-2.11.4
    ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc
    make
    sudo make install
    # sudo make uninstall
    sudo /usr/share/openvswitch/scripts/ovs-ctl start
fi

sudo sed -i "/exit 0$/i /usr/share/openvswitch/scripts/ovs-ctl start" /etc/rc.local

# Finish
echo -e "${YELLOW}*** Installation Finished! ***${NC}"
