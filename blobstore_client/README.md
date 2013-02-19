# Ruby client for Blobstores

Lets BOSH access multiple blobstores using a unified API.

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

> Dir['/tmp/local_blobstore/**']
 => ["/tmp/local_blobstore/ef00746b-21ec-4473-a888-bf257cb7ea21"] 
```

