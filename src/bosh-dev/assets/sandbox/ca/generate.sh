#!/bin/bash

certDir=`dirname $0`/certs
rm -rf $certDir
mkdir -p $certDir
cd $certDir
function cleanup () { name=$1
  rm ${name}.csr
}

function createCertWithCA () { name=$1
  echo "Generating $name cert signed by CA..."

  openssl req -nodes -new -sha256 -newkey rsa:2048 -out ${name}.csr -keyout ${name}.key -subj '/C=US/O=BOSH/CN=localhost'
  openssl x509 -req -sha256 -in ${name}.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out ${name}.crt -days 99999 -extfile ../../openssl_san.cnf
  cleanup $name
}

function createSelfSignedCert () { name=$1
  echo "Generating self-signed $name cert..."
  openssl req -sha256 -nodes -new -sha256 -newkey rsa:2048 -out ${name}.csr -keyout ${name}.key -subj '/C=US/O=Pivotal/CN=localhost'
  openssl x509 -req -in ${name}.csr -signkey ${name}.key -out ${name}.crt -days 99999 -extfile ../../openssl_san.cnf
  cleanup $name
}

echo "Generating CA..."


openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -days 99999 -out rootCA.pem -subj '/C=AU/ST=Some-State/O=Internet Widgits Pty Ltd'

createCertWithCA server
createSelfSignedCert serverWithWrongCA

echo "Done!"
