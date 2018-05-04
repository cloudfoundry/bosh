FROM bosh/main-ruby-go

# install extra utils {
RUN \
  apt-get update \
  && apt-get install -y \
    debootstrap sudo
# }

# setup chroot env {
RUN \
  mkdir -p /tmp/ubuntu-chroot \
  && (debootstrap --arch amd64 trusty /tmp/ubuntu-chroot http://archive.ubuntu.com/ubuntu/ || true) # debootstrap attempts to mount the proc which requires privileged. Hence continue and mount proc fs in entrypoint
RUN \
  cp /etc/passwd /tmp/ubuntu-chroot/etc/ \
  && (sed 's/\([^:]*\):[^:]*:/\1:*:/' /etc/shadow | sudo tee /tmp/ubuntu-chroot/etc/shadow) \
  && cp /etc/group /tmp/ubuntu-chroot/etc/ \
  && cp /etc/hosts /tmp/ubuntu-chroot/etc/ # avoid sudo warnings when it tries to resolve the chroot's hostname
RUN \
  echo /proc /tmp/ubuntu-chroot/proc none rbind 0 0 >> /etc/fstab \
  && echo /dev /tmp/ubuntu-chroot/dev none rbind 0 0  >> /etc/fstab \
  && echo /sys /tmp/ubuntu-chroot/sys none rbind 0 0 >> /etc/fstab \
  && echo /tmp /tmp/ubuntu-chroot/tmp none rbind 0 0 >> /etc/fstab \
  && echo /var/lib /tmp/ubuntu-chroot/var/lib none rbind 0 0 >> /etc/fstab

ENV SHELLOUT_CHROOT_DIR /tmp/ubuntu-chroot
ENV LC_ALL C
# }
