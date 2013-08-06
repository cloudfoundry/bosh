require 'fog'

require 'bosh/dev'

module Bosh::Dev
  class PipelineStorage
    def download(bucket_name, remote_directory_path, file_name)
      s3_uri = uri(bucket_name, remote_directory_path, file_name)
      Net::HTTP.start(s3_uri.host) do |http|
        http.request_get(s3_uri.request_uri) do |response|
          raise "remote file '#{File.join(remote_directory_path, file_name)}' not found" if response.kind_of? Net::HTTPNotFound

          File.open(file_name, 'wb') do |file|
            response.read_body do |chunk|
              file.write(chunk)
            end
          end
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

    def fog_storage
      return @cached_storage if @cached_storage
      fog_options = {
        provider: 'AWS',
        aws_access_key_id: ENV.to_hash.fetch('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'),
        aws_secret_access_key: ENV.to_hash.fetch('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT')
      }
      @cached_storage = Fog::Storage.new(fog_options)
    end

    private

    attr_accessor :cached_storage

    def bucket(bucket_name)
      fog_storage.directories.get(bucket_name) || raise("bucket '#{bucket_name}' not found")
    end

    def uri(bucket_name, remote_directory_path, file_name)
      remote_file_path = File.join(remote_directory_path, file_name)
      URI.parse("http://#{bucket_name}.s3.amazonaws.com/#{remote_file_path}")
    end
  end
end