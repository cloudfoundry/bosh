require 'cli/common/common'
require 'cli/blobstore_client/errors'
require 'cli/blobstore_client/client'

Bosh::Cli::Blobstore.autoload(:BaseClient, 'cli/blobstore_client/base')
require 'cli/blobstore_client/retryable_blobstore_client'
require 'cli/blobstore_client/sha1_verifiable_blobstore_client'

Bosh::Cli::Blobstore.autoload(:S3BlobstoreClient, 'cli/blobstore_client/s3_blobstore_client')
Bosh::Cli::Blobstore.autoload(:SimpleBlobstoreClient, 'cli/blobstore_client/simple_blobstore_client')
Bosh::Cli::Blobstore.autoload(:LocalClient, 'cli/blobstore_client/local_client')
Bosh::Cli::Blobstore.autoload(:DavBlobstoreClient, 'cli/blobstore_client/dav_blobstore_client')
Bosh::Cli::Blobstore.autoload(:DavcliBlobstoreClient, 'cli/blobstore_client/davcli_blobstore_client')
Bosh::Cli::Blobstore.autoload(:S3cliBlobstoreClient, 'cli/blobstore_client/s3cli_blobstore_client')
