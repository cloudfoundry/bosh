# NATS 

BOSH uses a custom version of GNATSD (Go edition of NATS) to support TLS & NON-TLS on the same port.

The fork lives here : [https://github.com/cloudfoundry/gnatsd](https://github.com/cloudfoundry/gnatsd)

### How to update GNATSD version: 

- Pull changes of the forked gnatsd by running the script bin/update-gnatsd. This script will fetch the code of https://github.com/cloudfoundry/gnatsd , bosh-gnatsd branch, and dump it in src/go/src/github.com/nats-io/gnatsd.

At each run of the bin/update-gnatsd, a text file gnatsd-version.txt will be created/changed to point towards the latest commit of https://github.com/cloudfoundry/gnatsd , bosh-gnatsd branch. This is to track the version of gnatsd that was pulled in.