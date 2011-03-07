module Bosh::Agent
  class Util


    class BindingHelper
      attr_reader :name
      attr_reader :index
      attr_reader :properties
      attr_reader :spec

      def initialize(name, index, properties, spec)
        @name = name
        @index = index
        @properties = properties
        @spec = spec
      end

      def get_binding
        binding
      end
    end

    class << self
      def unpack_blob(blobstore_id, sha1, install_path)
        base_dir = Bosh::Agent::Config.base_dir
        logger = Bosh::Agent::Config.logger

        bsc_options = Bosh::Agent::Config.blobstore_options
        bsc_provider = Bosh::Agent::Config.blobstore_provider
        blobstore_client = Bosh::Blobstore::Client.create(bsc_provider, bsc_options)

        data_tmp = File.join(base_dir, 'data', 'tmp')
        FileUtils.mkdir_p(data_tmp)

        begin
          tf = Tempfile.open(blobstore_id, data_tmp)
          logger.info("Retrieving blob: #{blobstore_id}")

          blobstore_client.get(blobstore_id, tf)
          logger.info("Done retrieving blob")

          tf.flush
          blob_data_file = tf.path

          logger.info("creating #{install_path}")
          FileUtils.mkdir_p(install_path)

          blob_sha1 = Digest::SHA1.file(blob_data_file).hexdigest
          logger.info("hexdigest of #{blob_data_file}")

          unless blob_sha1 == sha1
            raise Bosh::Agent::MessageHandlerError, "Expected sha1: #{sha1}, Downloaded sha1: #{blob_sha1}"
          end

          logger.info("Installing to: #{install_path}")
          Dir.chdir(install_path) do
            output = `tar zxvf #{blob_data_file}`
            raise Bosh::Agent::MessageHandlerError,
              "Failed to unpack blob: #{output}" unless $?.exitstatus == 0
          end
        rescue Exception => e
          logger.info("Failure unpacking blob: #{e.inspect} #{e.backtrace}")
          raise e
        ensure
          tf.close
          tf.unlink
        end

      end

      # Provide binding for a particular variable
      def config_binding(config)
        name = config['job']['name']
        index = config['index']
        properties = config['properties'].to_openstruct
        spec = config.to_openstruct
        BindingHelper.new(name, index, properties, spec).get_binding
      end

      def partition_disk(dev, sfdisk_input)
        logger = Bosh::Agent::Config.logger
        if File.blockdev?(dev)
          sfdisk_cmd = "echo \"#{sfdisk_input}\" | sfdisk -uM #{dev}"
          output = %x[#{sfdisk_cmd}]
          unless $? == 0
            logger.info("failed to parition #{dev}")
            logger.info(ouput)
          end
        end
      end

      def settings
        base_dir = Bosh::Agent::Config.base_dir
        settings_dir = File.join(base_dir, 'bosh', 'settings')

        begin
          File.read('/dev/cdrom', 0)
        rescue Errno::E123 # ENOMEDIUM
          raise Bosh::Agent::LoadSettingsError, 'No bosh cdrom env'
        end

        FileUtils.mkdir_p(settings_dir)
        FileUtils.chmod(700, settings_dir)

        output = `mount /dev/cdrom #{settings_dir} 2>&1`
        raise Bosh::Agent::LoadSettingsError,
          "Failed to mount settings on #{settings_dir}: #{output}" unless $?.exitstatus == 0

        settings_json = File.read(File.join(settings_dir, 'env'))

        `umount #{settings_dir} 2>&1`

        settings = Yajl::Parser.new.parse(settings_json)

        cache = File.join(base_dir, 'bosh', 'settings.json')
        File.open(cache, 'w') { |f| f.write(settings_json) }

        # Only eject cdrom after we have written the settings cache
        `eject /dev/cdrom`

        settings
      end

    end
  end
end
