#!/usr/bin/env bash

for package_name in \
  autoconf \
  bison \
  cmake \
  cpp \
  flex \
  gcc \
  gcc-c++ \
  gcc-gfortran \
  gettext \
  intltool \
  libmpc \
  libquadmath-devel \
  libstdc++-devel \
  make \
  patch \
; do
  rpm -ql $package_name | xargs file | grep -Ev ':\s+directory\s+$' | awk -F ':' '{ print $1 }'
done
