require 'digest/sha1'
require 'bosh/director/compiled_package'
require 'bosh/director/compiled_package/blob_sha_mismatch_error'

module Bosh::Director::CompiledPackage
  class CompiledPackage
    attr_reader :package_name, :package_fingerprint, :sha1, :stemcell_sha1, :blobstore_id, :blob_path

    def initialize(options = {})
      @package_name = options.fetch(:package_name)
      @package_fingerprint = options.fetch(:package_fingerprint)
      @sha1 = options.fetch(:sha1)
      @stemcell_sha1 = options.fetch(:stemcell_sha1)
      @blobstore_id = options.fetch(:blobstore_id)
      @blob_path = options.fetch(:blob_path)
    end

    def check_blob_sha
      if sha1 != actual_sha
        raise BlobShaMismatchError, "Blob SHA mismatch in file #{blob_path}: expected: #{sha1}, got #{actual_sha}"
      end
    end

    private

    def actual_sha
      @actual_sha ||= Digest::SHA1.file(blob_path).hexdigest
    end
  end
end
