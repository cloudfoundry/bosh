require 'bosh/dev/upload_adapter'

module Bosh::Dev
  class LightStemcellPointer
    def initialize(light_stemcell)
      @light_stemcell = light_stemcell
    end

    def promote
      upload_adapter = UploadAdapter.new
      upload_adapter.upload(
        bucket_name: 'bosh-jenkins-artifacts',
        key: 'last_successful-bosh-stemcell-aws_ami_us-east-1',
        body: @light_stemcell.ami_id,
        public: true
      )
    end
  end
end
