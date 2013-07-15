require 'fog'

module Bosh
  module Dev
    class Pipeline

      def initialize(options={})
        @fog_storage = options.fetch(:fog_storage) do
          fog_options = {
              provider: 'AWS',
              aws_access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'),
              aws_secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT')
          }
          Fog::Storage.new(fog_options)
        end
      end

      def publish_stemcell(stemcell)
        latest_filename = latest_stemcell_filename(stemcell.infrastructure, stemcell.name, stemcell.light?)
        s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

        s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))
        s3_upload(stemcell.path, s3_path)
        s3_upload(stemcell.path, s3_latest_path)
      end

      def bucket
        'bosh-ci-pipeline'
      end

      def s3_upload(file, remote_path)
        directory = fog_storage.directories.get(bucket)
        directory.files.create(key: remote_path, body: File.open(file))
      end

      def download_stemcell(version, options={})
        infrastructure = options.fetch(:infrastructure)
        name           = options.fetch(:name)
        light          = options.fetch(:light)

        filename = stemcell_filename(version, infrastructure, name, light)
        bucket_files = fog_storage.directories.get(bucket).files

        File.open(filename, 'w') do |file|
          bucket_files.get(File.join(name, infrastructure, filename)) do |chunk|
            file.write(chunk)
          end
        end
      end

      def download_latest_stemcell(options={})
        infrastructure = options.fetch(:infrastructure)
        name           = options.fetch(:name)
        light          = options.fetch(:light, false)

        download_stemcell('latest', infrastructure: infrastructure, name: name, light: light)
      end

      def latest_stemcell_filename(infrastructure, name, light)
        stemcell_filename('latest', infrastructure, name, light)
      end

      private
      attr_reader :fog_storage

      def stemcell_filename(version, infrastructure, name, light)
        stemcell_filename_parts = []
        stemcell_filename_parts << version if version == 'latest'
        stemcell_filename_parts << 'light' if light
        stemcell_filename_parts << name
        stemcell_filename_parts << infrastructure
        stemcell_filename_parts << version unless version == 'latest'

        "#{stemcell_filename_parts.join('-')}.tgz"
      end
    end
  end
end
