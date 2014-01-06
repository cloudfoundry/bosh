#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# gmp
gmp_basename=gmp-5.1.3
gmp_archive=$gmp_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$gmp_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $gmp_archive
  cd $gmp_basename
  ./configure
  make && make install
"

# nettle
nettle_basename=nettle-2.7.1
nettle_archive=$nettle_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$nettle_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $nettle_archive
  cd $nettle_basename
  ./configure --disable-openssl
  make && make install
"

# gnutls
gnutls_basename=gnutls-3.2.6
gnutls_archive=$gnutls_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$gnutls_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $gnutls_archive
  cd $gnutls_basename
  PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig ./configure --disable-doc
  make && make install
"

# libestr
libestr_basename=libestr-0.1.9
libestr_archive=$libestr_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$libestr_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $libestr_archive
  cd $libestr_basename
  ./configure
  make && make install
"

# json-c
jsonc_basename=json-c-0.11
jsonc_archive=$jsonc_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$jsonc_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $jsonc_archive
  cd $jsonc_basename
  ./configure
  make && make install
"

# librelp
librelp_basename=librelp-1.2.0
librelp_archive=$librelp_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$librelp_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $librelp_archive
  cd $librelp_basename
  PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig LD_RUN_PATH=/usr/local/lib ./configure
  make && make install
"

# Rsyslog
rsyslog_basename=rsyslog-7.4.6
rsyslog_archive=$rsyslog_basename.tar.gz

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/$rsyslog_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
  cd src
  tar zxvf $rsyslog_archive
  cd $rsyslog_basename
  PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig LD_RUN_PATH=/usr/local/lib ./configure --enable-relp --enable-cached-man-pages
  make && make install
"

# Add configuration files
cp $assets_dir/rsyslog.conf $chroot/etc/rsyslog.conf
cp $assets_dir/rsyslog_upstart.conf $chroot/etc/init/rsyslog.conf
cp $assets_dir/rsyslog_logrotate.conf $chroot/etc/logrotate.d/rsyslog

mkdir -p $chroot/etc/rsyslog.d
cp -f $assets_dir/rsyslog_50-default.conf $chroot/etc/rsyslog.d/50-default.conf

# Add user/group
run_in_bosh_chroot $chroot "
  useradd --system --user-group --no-create-home syslog || true
"

# Configure /var/log directory
filenames=( auth.log daemon.log debug kern.log lpr.log mail.err mail.info \
              mail.log mail.warn messages syslog user.log )

for filename in ${filenames[@]}
do
  fullpath=/var/log/$filename
  run_in_bosh_chroot $chroot "
    touch ${fullpath} && chown syslog:adm ${fullpath} && chmod 640 ${fullpath}
  "
done

# init.d configuration is different for each OS
if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  run_in_bosh_chroot $chroot "
    ln -sf /lib/init/upstart-job /etc/init.d/rsyslog
    update-rc.d rsyslog defaults
  "
elif [ -f $chroot/etc/centos-release ] # Centos
then
  cp $assets_dir/centos_init_d $chroot/etc/init.d/rsyslog
  run_in_bosh_chroot $chroot "
    chmod 0755 /etc/init.d/rsyslog
    chkconfig --add rsyslog
  "
else
  echo "Unknown OS, exiting"
  exit 2
fi

# Point system installed rsyslog to custom installed one
run_in_bosh_chroot $chroot "
  if [ -f /sbin/rsyslogd ]; then
    ln -sf /usr/local/sbin/rsyslogd /sbin/rsyslogd
  fi
  
  if [ -f /usr/sbin/rsyslogd ]; then
    ln -sf /usr/local/sbin/rsyslogd /usr/sbin/rsyslogd
  fi
"
