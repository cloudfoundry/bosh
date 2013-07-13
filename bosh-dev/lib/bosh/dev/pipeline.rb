module Bosh
  module Dev
    class Pipeline
      def publish_stemcell(stemcell)
        latest_filename_parts = ['latest']
        latest_filename_parts << 'light' if stemcell.is_light?
        latest_filename_parts << stemcell.name
        latest_filename_parts << stemcell.infrastructure

        latest_filename = "#{latest_filename_parts.join('-')}.tgz"
        s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

        s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))
        s3_upload(stemcell.path, s3_path)
        s3_copy("s3://#{bucket}/" + s3_path, "s3://#{bucket}/" + s3_latest_path, true)
      end

      def bucket
        'bosh-ci-pipeline'
      end

      def s3_upload(file, remote_path)
        remote_uri = File.join('s3://', bucket, remote_path)
        Rake::FileUtilsExt.sh("s3cmd put #{file} #{remote_uri}")
      end

      def download_stemcell(version, options={})
        infrastructure = options.fetch(:infrastructure)
        name           = options.fetch(:name)
        light          = options.fetch(:light)

        s3_uri = File.join("s3://#{bucket}/", name, infrastructure, stemcell_filename(version, infrastructure, name, light))

        Rake::FileUtilsExt.sh("s3cmd -f get #{s3_uri}")
      end

      def download_latest_stemcell(args={})
        infrastructure = args.fetch(:infrastructure)
        name           = args.fetch(:name)
        light          = args.fetch(:light, false)

        s3_uri = File.join("s3://#{bucket}/", name, infrastructure, latest_stemcell_filename(infrastructure, name, light))

        Rake::FileUtilsExt.sh("s3cmd -f get #{s3_uri}")
      end

      def latest_stemcell_filename(infrastructure, name, light)
        stemcell_filename_parts = []
        stemcell_filename_parts << 'latest'
        stemcell_filename_parts << 'light' if light
        stemcell_filename_parts << name
        stemcell_filename_parts << infrastructure

        "#{stemcell_filename_parts.join('-')}.tgz"
      end

      private
      def stemcell_filename(version, infrastructure, name, light)
        stemcell_filename_parts = []
        stemcell_filename_parts << 'light' if light
        stemcell_filename_parts << name
        stemcell_filename_parts << infrastructure
        stemcell_filename_parts << version

        "#{stemcell_filename_parts.join('-')}.tgz"
      end

      def s3_copy(src_uri, dst_uri, overwrite=false)
        overwrite_flag = overwrite ? '--force' : ''
        Rake::FileUtilsExt.sh("s3cmd cp #{overwrite_flag} #{src_uri} #{dst_uri}")
      end
    end
  end
end
