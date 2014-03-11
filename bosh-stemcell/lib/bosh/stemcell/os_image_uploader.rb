module Bosh::Stemcell
  class OsImageUploader
    def initialize(dependencies = {})
      @digester = dependencies.fetch(:digester)
      @adapter = dependencies.fetch(:adapter)
    end

    def upload(bucket_name, os_image_path)
      digest = digester.file(os_image_path).hexdigest
      adapter.upload(
        bucket_name: bucket_name,
        key: digest,
        body: os_image_path,
        public: true,
      )
      digest
    end

    private

    attr_reader :digester, :adapter
  end
end
