#!/bin/bash

openssl req -nodes -new -newkey rsa:2048 -out ca.csr -keyout ca.key -subj '/C=US/O=Pivotal/CN=myapp.dev102.cf.com'
openssl x509 -req -days 3650 -in ca.csr -signkey ca.key -out ca.pem
