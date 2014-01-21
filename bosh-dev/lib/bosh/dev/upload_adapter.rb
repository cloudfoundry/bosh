require 'fog'

module Bosh::Dev
  class UploadAdapter

    def upload(options = {})
      @bucket_name = options.fetch(:bucket_name)
      @key = options.fetch(:key)
      @body = options.fetch(:body)
      @public = options.fetch(:public, false)

      bucket.files.create(
        key: key,
        body: body,
        public: public
      )
    end

    private

    attr_accessor :bucket_name, :key, :body, :public, :cached_storage

    def bucket
      fog_storage.directories.get(bucket_name) || raise("bucket '#{bucket_name}' not found")
    end

    def fog_storage
      return cached_storage if cached_storage

      fog_options = {
        provider: 'AWS',
        aws_access_key_id: ENV.to_hash.fetch('BOSH_AWS_ACCESS_KEY_ID'),
        aws_secret_access_key: ENV.to_hash.fetch('BOSH_AWS_SECRET_ACCESS_KEY')
      }

      @cached_storage = Fog::Storage.new(fog_options)
    end

  end

end
