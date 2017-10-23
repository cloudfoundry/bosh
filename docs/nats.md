# NATS 

BOSH uses a custom version of GNATSD (Go edition of NATS) to support TLS & NON-TLS on the same port.

The fork lives here : [https://github.com/cloudfoundry/gnatsd](https://github.com/cloudfoundry/gnatsd)

### How to update GNATSD version: 

- Get the latest binary from the [gnatsd
  pipeline](https://main.bosh-ci.cf-app.com/teams/main/pipelines/gnatsd)
and update the blob
