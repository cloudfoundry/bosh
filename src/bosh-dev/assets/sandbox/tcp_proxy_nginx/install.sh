set -e -x

echo "Extracting nginx..."
tar xzvf nginx-1.12.1.tar.gz

echo "Building nginx..."

pushd nginx-1.12.1
  ./configure \
    --prefix=${BOSH_INSTALL_TARGET} \
    --with-stream \
    --without-http_rewrite_module \
    --with-cc-opt="-I/usr/local/opt/openssl/include" \
    --with-ld-opt="-L/usr/local/opt/openssl/lib"

  make
  make install
popd
