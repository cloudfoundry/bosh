# Ruby client for Blobstores
Copyright (c) 2009-2013 VMware, Inc.

Lets BOSH access multiple blobstores using a unified API.

## Usage

    bin/blobstore_client_console [<options>]
        -p, --provider PROVIDER Bosh Blobstore provider
        -c, --config FILE       Bosh Blobstore configuration file

## Console

To explore the client API for accessing a blobstore, try creating and using a local blobstore:

```
$ gem install blobstore_client
$ blobstore_client_console -p local -c config/local.yml.example
=> Welcome to BOSH blobstore client console
You can use 'bsc' to access blobstore client methods
> bsc.create("this is a test blob")
=> "ef00746b-21ec-4473-a888-bf257cb7ea21"
> bsc.get("ef00746b-21ec-4473-a888-bf257cb7ea21")
=> "this is a test blob"
> bsc.exists?("ef00746b-21ec-4473-a888-bf257cb7ea21")
=> true
> Dir['/tmp/local_blobstore/**']
=> ["/tmp/local_blobstore/ef00746b-21ec-4473-a888-bf257cb7ea21"]
> bsc.delete("ef00746b-21ec-4473-a888-bf257cb7ea21")
=> true
```

## Configuration

These options are passed to the Bosh Blobstore client when it is instantiated.

### Local

These are the options for the Blobstore client when provider is `local`:

* `blobstore_path` (required)
  Path for the blobstore

### Simple

These are the options for the Blobstore client when provider is `simple`:

* `endpoint` (required)
  Blobstore endpoint
* `user` (optional)
  Blobstore User
* `password` (optional)
  Blobstore Password
* `bucket` (optional, by default `resources`)
  Name of the bucket

### Amazon S3

These are the options for the Blobstore client when provider is `s3`:

* `bucket_name` (required)
  Name of the S3 bucket
* `encryption_key` (optional)
  Encryption_key that is applied before the object is sent to S3
* `credentials_source` (optional)
  Where to get AWS credentials. This can be set to `static` for to use an `access_key_id` and `secret_access_key` or `env_or_profile` to get the credentials from environment variables or an EC2 instance profile. Defaults to `static` if not set.
* `access_key_id` (optional, if not present and `credentials_source` is `static`, the blobstore client operates in read only mode)
  S3 Access Key
* `secret_access_key` (optional, if not present and `credentials_source` is `static`, the blobstore client operates in read only mode)
  S3 Secret Access Key
