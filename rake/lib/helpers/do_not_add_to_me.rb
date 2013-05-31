module Bosh
  module Helpers
    module DoNotAddToMe # Extract objects out of me instead...
      def publish_stemcell(infrastructure, type)
        path = Dir.glob("/mnt/stemcells/#{infrastructure}-#{type}/work/work/*-stemcell-*-#{candidate_build_number}.tgz").first
        if path
          sh("s3cmd put #{path} #{s3_stemcell_base_url(infrastructure, type)}")
        end
      end

      def download_latest_stemcell(infrastructure, type)
        version_cmd = "s3cmd ls  #{s3_stemcell_base_url(infrastructure, type)} " +
            "| sed -e 's/.*bosh-ci-pipeline.*stemcell-#{infrastructure}-\\(.*\\)\.tgz/\\1/' " +
            "| sort -n | tail -1"
        version = %x[#{version_cmd}].chomp

        stemcell_filename = "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}-#{version}.tgz"
        latest_stemcell_url = s3_stemcell_base_url(infrastructure, type) + stemcell_filename
        sh("s3cmd -f get #{latest_stemcell_url}")
        ln_s("#{stemcell_filename}", "#{type == 'micro' ? 'micro-' : ''}bosh-stemcell-#{infrastructure}.tgz", force: true)
      end

      def current_build_number
        ENV['BUILD_NUMBER']
      end

      def candidate_build_number
        if ENV['CANDIDATE_BUILD_NUMBER'].to_s.empty?
          raise 'Please set the CANDIDATE_BUILD_NUMBER environment variable'
        end

        ENV['CANDIDATE_BUILD_NUMBER']
      end

      def s3_release_url(build_number)
        "s3://bosh-ci-pipeline/bosh-#{build_number}.tgz"
      end

      def s3_stemcell_base_url(infrastructure, type)
        "s3://bosh-ci-pipeline/stemcells/#{infrastructure}/#{type}/"
      end
    end
  end
end
