FROM bosh/main-ruby-go

RUN apt-get update && apt-get install -y debootstrap
RUN mkdir -p /tmp/ubuntu-chroot
RUN debootstrap --arch amd64 trusty /tmp/ubuntu-chroot http://archive.ubuntu.com/ubuntu/ || true # debootstrap attempts to mount the proc which requires privileged. Hence continue and mount proc fs in entrypoint
ADD mount_proc.sh /tmp/mount_proc.sh
ENTRYPOINT "/tmp/mount_proc.sh"
