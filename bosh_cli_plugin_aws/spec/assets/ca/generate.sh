#!/bin/bash

NAME=$1
SUBJECT=$2

openssl req -nodes -new -newkey rsa:1024 -out $NAME.csr -keyout $NAME.key -subj $SUBJECT
openssl x509 -req -days 3650 -in $NAME.csr -signkey $NAME.key -out $NAME.pem
