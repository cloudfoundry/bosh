require 'fog'
require 'logger'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class BulkUploader
    def initialize(pipeline = Pipeline.new)
      @pipeline = pipeline
    end

    def upload_r(source_dir, dest_dir)
      Dir.chdir(source_dir) do
        Dir['**/*'].each do |file|
          unless File.directory?(file)
            pipeline.create(
              key: File.join(dest_dir, file),
              body: File.open(file),
              public: true
            )
          end
        end
      end
    end

    private

    attr_reader :pipeline
  end
end
