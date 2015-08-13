# BOSH Registry
Copyright (c) 2009-2013 VMware, Inc.

For online documentation see: http://rubydoc.info/gems/bosh-registry/

## Usage

    bin/bosh-registry-migrate [<options>]
        -c, --config FILE  Bosh Registry configuration file

    bin/bosh-registry [<options>]
        -c, --config FILE  Bosh Registry configuration file

## Configuration

These options are passed to the Bosh Registry when it is instantiated.

### Registry options

These are the options for the Registry HTTP server (by default server is
bound to address 0.0.0.0):

* `port` (required)
  Registry port
* `user` (required)
  Registry user (for HTTP Basic authentication)
* `password` (required)
  Registry password (for HTTP Basic authentication)

### Database options

These are the options for the database connection where registry will store
instance properties:

* `database` (required)
  DB connection URI
* `max_connections` (required)
  Maximum size of the connection pool
* `pool_timeout` (required)
  Number of seconds to wait if a connection cannot be acquired before
  raising an error

### Cloud options

These are the options for the cloud connection where registry will fetch for
the IP addresses belonging to a instances:

* `plugin` (required)
  Cloud Provider (currently supported: aws and openstack)

#### AWS options

These are the credentials to connect to AWS services:

* `access_key_id` (required)
  IAM Access Key ID
* `secret_access_key` (required)
  AWS IAM Secret Access Key
* `region` (required)
  AWS EC2 Region
* `max_retries` (optional, defaults to 2)
  Max number of retries to connect to AWS

#### OpenStack options

These are the credentials to connect to OpenStack services:

* `auth_url` (required)
  URL of the OpenStack Identity endpoint to connect to
* `username` (required)
  OpenStack user name
* `api_key` (required)
  OpenStack API key
* `tenant` (required)
  OpenStack tenant name
* `domain` (optional)
  OpenStack domain
* `region` (optional)
  OpenStack region
* `endpoint_type` (optional)
  OpenStack endpoint type (publicURL (default), adminURL, internalURL)
* `connection_options` (optional)
  Hash containing optional connection parameters to the OpenStack API (`ssl_verify_peer`, `omit_default_port`, ...)

## Example

This is a sample of an Bosh Registry configuration file:

    ---
    loglevel: debug

    http:
      port: 25695
      user: admin
      password: admin

    db:
      database: "sqlite:///:memory:"
      max_connections: 32
      pool_timeout: 10

    cloud:
      plugin: openstack
      openstack:
        auth_url: "http://127.0.0.1:5000/v3.0"
        username: foo
        api_key: bar
        tenant: foo
        domain: bar
        region: