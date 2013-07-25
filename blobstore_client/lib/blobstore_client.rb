# Copyright (c) 2009-2012 VMware, Inc.

require 'common/common'
require 'blobstore_client/version'
require 'blobstore_client/errors'
require 'blobstore_client/client'

Bosh::Blobstore.autoload(:BaseClient, 'blobstore_client/base')
Bosh::Blobstore.autoload(:S3BlobstoreClient, 'blobstore_client/s3_blobstore_client')
Bosh::Blobstore.autoload(:SimpleBlobstoreClient, 'blobstore_client/simple_blobstore_client')
Bosh::Blobstore.autoload(:SwiftBlobstoreClient, 'blobstore_client/swift_blobstore_client')
Bosh::Blobstore.autoload(:AtmosBlobstoreClient, 'blobstore_client/atmos_blobstore_client')
Bosh::Blobstore.autoload(:LocalClient, 'blobstore_client/local_client')
Bosh::Blobstore.autoload(:DavBlobstoreClient, 'blobstore_client/dav_blobstore_client')