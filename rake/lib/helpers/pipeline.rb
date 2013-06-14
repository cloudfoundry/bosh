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

        s3_upload(stemcell.path, base_url + s3_path)
        s3_copy(base_url + s3_path, base_url + s3_latest_path, true)
      end

      def base_url
        "s3://bosh-ci-pipeline/"
      end

      def s3_upload(file, remote_uri)
        Rake::FileUtilsExt.sh("s3cmd put #{file} #{remote_uri}")
      end

      def s3_copy(src_uri, dst_uri, overwrite=false)
        overwrite_flag = overwrite ? '--force' : ''
        Rake::FileUtilsExt.sh("s3cmd cp #{overwrite_flag} #{src_uri} #{dst_uri}")
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
