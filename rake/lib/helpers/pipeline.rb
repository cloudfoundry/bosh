module Bosh
  module Helpers
    class Pipeline

      def publish_stemcell(stemcell)
        s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))
        latest_filename_parts = ['latest']
        latest_filename_parts << 'light' if stemcell.is_light?
        latest_filename_parts << stemcell.name
        latest_filename_parts << stemcell.infrastructure

        latest_filename = "#{latest_filename_parts.join('-')}.tgz"
        s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

        Rake::FileUtilsExt.sh("s3cmd put #{stemcell.path} #{base_url+s3_path}")
        Rake::FileUtilsExt.sh("s3cmd cp #{base_url+s3_path} #{base_url+s3_latest_path}")
      end

      def base_url
        "s3://bosh-ci-pipeline/"
      end

      def download_latest_stemcell(args={})
        infrastructure = args.fetch(:infrastructure)
        name           = args.fetch(:name)
        light          = args.fetch(:light, false)
        s3_path        = File.join(base_url, name, infrastructure) + '/'

        stemcell_filename = "latest-#{light ? 'light-' : ''}#{name}-#{infrastructure}.tgz"
        latest_stemcell_url = s3_path + stemcell_filename
        Rake::FileUtilsExt.sh("s3cmd -f get #{latest_stemcell_url}")
      end

    end
  end
end
