set -e -x

echo "Extracting nginx..."
tar xzvf nginx-1.9.6.tar.gz

echo "Building nginx..."

pushd nginx-1.9.6
  ./configure \
    --prefix=${BOSH_INSTALL_TARGET} \
    --with-stream \
    --without-http_rewrite_module

  make
  make install
popd
