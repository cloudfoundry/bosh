require 'bosh/director/compiled_package'

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

  end
end
