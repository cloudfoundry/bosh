module Bosh
  module Helpers
    class Pipeline < Struct.new(:infrastructure, :type)
      def publish(path)
        Rake::FileUtilsExt.sh("s3cmd put #{path} #{base_url}")
      end

      def base_url
        "s3://bosh-ci-pipeline/stemcells/#{infrastructure}/#{type}/"
      end
    end
  end
end
