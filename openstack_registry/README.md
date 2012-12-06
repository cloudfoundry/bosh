# BOSH OpenStack Registry
Copyright (c) 2009-2012 VMware, Inc.

For online documentation see: http://rubydoc.info/gems/bosh_openstack_registry/

## Usage

    bin/migrate [<options>]
        -c, --config FILE  OpenStack Registry configuration file

    bin/openstack_registry [<options>]
        -c, --config FILE  OpenStack Registry configuration file

## Configuration

These options are passed to the OpenStack Registry when it is instantiated.

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
server properties:

* `database` (required)
  DB connection URI
* `max_connections` (required)
  Maximum size of the connection pool
* `pool_timeout` (required)
  Number of seconds to wait if a connection cannot be acquired before
  raising an error

### OpenStack options

These are the credentials to connect to OpenStack services:

* `auth_url` (required)
  URL of the OpenStack Identity endpoint to connect to
* `username` (required)
  OpenStack user name
* `api_key` (required)
  OpenStack API key
* `tenant` (required)
  OpenStack tenant name
* `region` (optional)
  OpenStack region

## Example

This is a sample of an OpenStack Registry configuration file:

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

    openstack:
      auth_url: "http://127.0.0.1:5000/v2.0/tokens"
      username: foo
      api_key: bar
      tenant: foo
      region: