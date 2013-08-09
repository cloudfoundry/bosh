require 'fog'
require 'logger'

require 'bosh/dev/build'
require 'bosh/stemcell/infrastructure'
require 'bosh/dev/pipeline_storage'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class Pipeline
    def initialize(options = {})
      @build_id = options.fetch(:build_id) { Build.candidate.number.to_s }
      @logger = options.fetch(:logger) { Logger.new($stdout) }
    end

    def upload_r(source_dir, dest_dir)
      Build.candidate.upload_gems(source_dir, dest_dir)
    end

    def publish_stemcell(stemcell)
      Build.candidate.upload_stemcell(stemcell)
    end

    def gems_dir_url
      Build.candidate.gems_dir_url
    end

    private

    attr_reader :logger, :build_id
  end
end
