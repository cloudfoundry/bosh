require_relative 'build'

module Bosh
  module Helpers
    class S3Stemcell < Struct.new(:infrastructure, :type)
      def publish
        path = Dir.glob("/mnt/stemcells/#{infrastructure}-#{type}/work/work/*-stemcell-*-#{Build.candidate.number}.tgz").first
        if path
          Rake::FileUtilsExt.sh("s3cmd put #{path} #{base_url}")
        end
      end

      def download_latest
        version_cmd = "s3cmd ls  #{base_url} " +
            "| sed -e 's/.*bosh-ci-pipeline.*stemcell-#{infrastructure}-\\(.*\\)\.tgz/\\1/' " +
            "| sort -n | tail -1"
        version = %x[#{version_cmd}].chomp

        stemcell_filename = "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}-#{version}.tgz"
        latest_stemcell_url = base_url + stemcell_filename
        Rake::FileUtilsExt.sh("s3cmd -f get #{latest_stemcell_url}")
        FileUtils.ln_s("#{stemcell_filename}", "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}.tgz", force: true)
      end

      private
      def base_url
        "s3://bosh-ci-pipeline/stemcells/#{infrastructure}/#{type}/"
      end
    end
  end
end
