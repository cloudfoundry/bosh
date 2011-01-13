module Bosh::Agent
  class Util
    class << self
      def unpack_blob(blobstore_id, install_path)
        base_dir = Bosh::Agent::Config.base_dir

        bsc_options = Bosh::Agent::Config.blobstore_options
        blobstore_client = Bosh::Blobstore::SimpleBlobstoreClient.new(bsc_options)

        data_tmp = File.join(base_dir, 'data', 'tmp')
        FileUtils.mkdir_p(data_tmp)

        Tempfile.open(blobstore_id, data_tmp) do |tf|
          tf.write(blobstore_client.get(blobstore_id))
          tf.flush

          FileUtils.mkdir_p(install_path)

          blob_data_file = tf.path

          Dir.chdir(install_path) do
            output = `tar zxvf #{blob_data_file}`
            raise Bosh::Agent::MessageHandlerError,
              "Failed to unpack blob: #{output}" unless $?.exitstatus == 0
          end
        end

      end

      # Provide binding for a particular variable
      def config_binding(config)
        config = config
        binding
      end

    end
  end
end
