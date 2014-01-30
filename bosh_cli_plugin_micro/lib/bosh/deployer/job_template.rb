require 'tempfile'
require 'securerandom'

module Bosh::Deployer
  class JobTemplate

    class FetchError < Exception
    end

    attr_reader :name, :version, :sha1, :blobstore_id

    def initialize(template_spec, blobstore)
      @name = template_spec.fetch('name')
      @version = template_spec.fetch('version')
      @sha1 = template_spec.fetch('sha1')
      @blobstore_id = template_spec.fetch('blobstore_id')
      @blobstore = blobstore
    end

    def download_blob
      uuid = SecureRandom.uuid
      path = File.join(Dir.tmpdir, "template-#{uuid}")
      File.open(path, 'w') do |f|
        blobstore.get(blobstore_id, f)
      end
      path
    rescue Bosh::Blobstore::BlobstoreError => e
      if e.message.include?('Could not fetch object')
        raise FetchError.new
      else
        raise e
      end
    end

    private

    attr_reader :blobstore
  end
end
