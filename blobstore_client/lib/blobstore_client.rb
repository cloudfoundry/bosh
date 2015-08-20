require 'common/common'
require 'blobstore_client/version'
require 'blobstore_client/errors'
require 'blobstore_client/client'

Bosh::Blobstore.autoload(:BaseClient, 'blobstore_client/base')
require 'blobstore_client/retryable_blobstore_client'
require 'blobstore_client/sha1_verifiable_blobstore_client'

Bosh::Blobstore.autoload(:S3BlobstoreClient, 'blobstore_client/s3_blobstore_client')
Bosh::Blobstore.autoload(:SimpleBlobstoreClient, 'blobstore_client/simple_blobstore_client')
Bosh::Blobstore.autoload(:SwiftBlobstoreClient, 'blobstore_client/swift_blobstore_client')
Bosh::Blobstore.autoload(:LocalClient, 'blobstore_client/local_client')
Bosh::Blobstore.autoload(:DavBlobstoreClient, 'blobstore_client/dav_blobstore_client')
