FROM bosh/main-ruby-go

RUN groupadd -g 1000 ubuntu && useradd -u 1000 -g 1000 -m ubuntu && echo 'ubuntu ALL=NOPASSWD:ALL' >> /etc/sudoers

ADD scripts/update.sh /tmp/update.sh
RUN /tmp/update.sh && rm /tmp/update.sh

ENV OVF_TOOL_INSTALLER VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle
ENV OVF_TOOL_INSTALLER_SHA1 b907275c8d744bb54717d24bb8d414b19684fed4
ADD ${OVF_TOOL_INSTALLER} /tmp/ovftool_installer.bundle
ADD scripts/install-ovf.sh /tmp/install-ovf.sh
RUN /tmp/install-ovf.sh && rm /tmp/install-ovf.sh

# this is unshare from ubuntu 15.10 so we can use the newer -fp flags
ADD scripts/unshare /usr/bin/unshare

ADD scripts/ubuntu_bashrc /home/ubuntu/.bashrc

RUN for GO_EXECUTABLE in $GOROOT/bin/*; do ln -s $GO_EXECUTABLE /usr/bin/; done
