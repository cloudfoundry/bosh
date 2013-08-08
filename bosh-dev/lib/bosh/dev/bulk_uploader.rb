require 'fog'
require 'logger'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class BulkUploader
    def initialize(pipeline = Pipeline.new)
      @pipeline = pipeline
    end

    def upload_r(source_dir, dest_dir)
      pipeline.upload_r(source_dir, dest_dir)
    end

    private

    attr_reader :pipeline
  end
end
