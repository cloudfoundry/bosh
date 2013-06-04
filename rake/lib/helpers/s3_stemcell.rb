require 'rake'
require_relative 'build'
require_relative 'pipeline'

module Bosh
  module Helpers
    class S3Stemcell
      def initialize(infrastructure, type)
        @infrastructure, @type = infrastructure, type
        @pipeline = Pipeline.new(infrastructure, type)
      end

      def publish
        path = Dir.glob("/mnt/stemcells/#{infrastructure}-#{type}/work/work/*-stemcell-*-#{Build.candidate.number}.tgz").first
        if path
          pipeline.publish(path)
        end
      end

      def download_latest
        version_cmd = "s3cmd ls  #{pipeline.base_url} " +
            "| sed -e 's/.*bosh-ci-pipeline.*stemcell-#{infrastructure}-\\(.*\\)\.tgz/\\1/' " +
            "| sort -n | tail -1"
        version = %x[#{version_cmd}].chomp

        stemcell_filename = "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}-#{version}.tgz"
        latest_stemcell_url = pipeline.base_url + stemcell_filename
        Rake::FileUtilsExt.sh("s3cmd -f get #{latest_stemcell_url}")
        FileUtils.ln_s("#{stemcell_filename}", "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}.tgz", force: true)
      end

      private
      attr_reader :infrastructure, :type, :pipeline
    end
  end
end
