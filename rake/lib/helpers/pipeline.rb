module Bosh
  module Helpers
    class Pipeline
      def publish(local_path, s3_path)
        Rake::FileUtilsExt.sh("s3cmd put #{local_path} #{base_url+s3_path}")
      end

      def publish_stemcell(stemcell)
        s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))
        publish(stemcell.path, s3_path)
      end

      def base_url
        "s3://bosh-ci-pipeline/"
      end

      def download_latest_stemcell(args={})
        infrastructure = args.fetch(:infrastructure)
        name           = args.fetch(:name)
        light          = args.fetch(:light, false)
        s3_path        = File.join(base_url, name, infrastructure) + '/'

        version_cmd = "s3cmd ls #{s3_path} " +
            "| sed -e 's/.*#{light ? 'light-' : ''}#{name}-#{infrastructure}-\\(.*\\)\.tgz/\\1/' " +
            "| sort -n | tail -1"
        version = `#{version_cmd}`.chomp

        stemcell_filename = "#{light ? 'light-' : ''}#{name}-#{infrastructure}-#{version}.tgz"
        latest_stemcell_url = s3_path + stemcell_filename
        Rake::FileUtilsExt.sh("s3cmd -f get #{latest_stemcell_url}")
        FileUtils.ln_s("#{stemcell_filename}", "#{light ? 'light-' : ''}#{name}-#{infrastructure}.tgz", force: true)
      end

    end
  end
end
