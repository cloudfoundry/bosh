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
      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def logger
        Bosh::Agent::Config.logger
      end

      def unpack_blob(blobstore_id, sha1, install_path)
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
        if File.blockdev?(dev)
          sfdisk_cmd = "echo \"#{sfdisk_input}\" | sfdisk -uM #{dev}"
          output = %x[#{sfdisk_cmd}]
          unless $? == 0
            logger.info("failed to parition #{dev}")
            logger.info(output)
          end
        end
      end

      def block_device_size(block_device)
        unless File.blockdev?(block_device)
          raise Bosh::Agent::MessageHandlerError, "Not a blockdevice"
        end

        child = POSIX::Spawn::Child.new('/sbin/sfdisk', '-s', block_device)
        result = child.out
        unless result.match(/\A\d+\Z/) && child.status.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError,
            "Unable to determine disk size"
        end
        result.to_i
      end

      def run_hook(hook, job_template_name)
        hook_file = File.join(base_dir, 'jobs', job_template_name, 'bin', hook)

        unless File.exists?(hook_file)
          return nil
        end

        unless File.executable?(hook_file)
          raise Bosh::Agent::MessageHandlerError, "`#{hook}' hook for `#{job_template_name}' job is not an executable file"
        end

        env = {
          'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin',
        }

        child = POSIX::Spawn::Child.new(env, hook_file, :unsetenv_others => true)

        result = child.out
        logger.info("Hook #{hook} for job #{job_template_name}: #{result}")

        unless child.status.exitstatus == 0
          exception_message = "Hook #{hook} for #{job_template_name} failed "
          exception_message += "(exit: #{child.status.exitstatus}) "
          exception_message += " stderr: #{child.err}, stdout: #{result}"
          logger.info(exception_message)

          raise Bosh::Agent::MessageHandlerError, exception_message
        end
        result
      end

    end
  end
end
