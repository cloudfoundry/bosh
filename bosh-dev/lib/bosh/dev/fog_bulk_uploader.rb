require 'fog'
require 'logger'
require 'bosh/dev/pipeline'

module Bosh::Dev
  class FogBulkUploader
    attr_reader :base_dir, :fog_storage

    def initialize(pipeline=Pipeline.new)
      @base_dir = pipeline.bucket
      @fog_storage = pipeline.fog_storage
      @logger = Logger.new(STDOUT)
    end

    def upload_r(source_dir, dest_dir)
      Dir.chdir(source_dir) do
        Dir['**/*'].each do |file|
          unless File.directory?(file)
            uploaded_file = base_directory.files.create(
                key: File.join(dest_dir, file),
                body: File.open(file),
                public: true
            )
            @logger.info("uploaded #{file} to #{uploaded_file.public_url}")
          end
        end
      end
    end

    def base_directory
      fog_storage.directories.get(@base_dir) || raise("bucket '#{@base_dir}' not found")
    end
  end
end
