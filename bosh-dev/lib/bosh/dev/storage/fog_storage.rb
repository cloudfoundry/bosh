require 'fog'

require 'bosh/dev'

module Bosh::Dev::Storage
  class FogStorage

    attr_reader :fog_storage

    def initialize(fog_storage = default_fog_storage)
      @fog_storage = fog_storage
    end

    def download(bucket_name, remote_file_dir, file_name)
      remote_file_path = File.join(remote_file_dir, file_name)
      bucket_files = bucket(bucket_name).files
      raise "remote file '#{remote_file_path}' not found" unless bucket_files.head(remote_file_path)

      File.open(file_name, 'w') do |file|
        bucket_files.get(remote_file_path) do |chunk|
          file.write(chunk)
        end
      end
    end

    def upload(bucket_name, key, body, public)
      bucket(bucket_name).files.create(
        key: key,
        body: body,
        public: public
      )
    end

    private

    def bucket(bucket_name)
      fog_storage.directories.get(bucket_name) || raise("bucket '#{bucket_name}' not found")
    end

    def default_fog_storage
      fog_options = {
        provider: 'AWS',
        aws_access_key_id: ENV.to_hash.fetch('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'),
        aws_secret_access_key: ENV.to_hash.fetch('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT')
      }
      Fog::Storage.new(fog_options)
    end
  end
end