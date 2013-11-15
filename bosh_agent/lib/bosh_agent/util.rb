# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Util
    include Bosh::Exec

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
        blobstore_client = Bosh::Blobstore::Client.safe_create(bsc_provider, bsc_options)

        data_tmp = File.join(base_dir, 'data', 'tmp')
        FileUtils.mkdir_p(data_tmp)

        begin
          tf = Tempfile.open(blobstore_id, data_tmp)

          begin
            logger.info("Retrieving blob '#{blobstore_id}'")
            blobstore_client.get(blobstore_id, tf, sha1: sha1)
          rescue Bosh::Blobstore::BlobstoreError => e
            raise Bosh::Agent::MessageHandlerError.new(e.inspect)
          end

          partial_install_path = "#{install_path}-bosh-agent-unpack"
          logger.info("Creating '#{partial_install_path}'")
          FileUtils.rm_rf(partial_install_path)
          FileUtils.mkdir_p(partial_install_path)

          logger.info("Installing to '#{partial_install_path}'")
          Dir.chdir(partial_install_path) do
            output = `tar --no-same-owner -zxvf #{tf.path} 2>&1`
            unless $?.exitstatus == 0
              raise Bosh::Agent::MessageHandlerError.new('Failed to unpack blob', output)
            end
          end

          # Only move contents of the blob to install path at the end
          # to avoid corrupted package directory
          FileUtils.mv(partial_install_path, install_path)
        rescue Exception => e
          logger.info("Failure unpacking blob: #{e.inspect} #{e.backtrace}")
          raise e
        ensure
          if tf
            tf.close
            tf.unlink
          end
        end
      end

      # @param [Hash] Instance spec
      # @return [Binding] Template evaluation binding
      def config_binding(spec)
        Bosh::Common::TemplateEvaluationContext.new(spec).get_binding
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

      def lazy_itable_init_enabled?
        File.exists?("/sys/fs/ext4/features/lazy_itable_init")
      end

      def block_device_size(block_device)
        unless File.blockdev?(block_device)
          raise Bosh::Agent::MessageHandlerError, "Not a blockdevice"
        end

        result = sh("/sbin/sfdisk -s #{block_device} 2>&1")
        unless result.output.match(/\A\d+\Z/)
          raise Bosh::Agent::MessageHandlerError,
            "Unable to determine disk size"
        end
        result.output.to_i
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

        stdout_rd, stdout_wr = IO.pipe
        stderr_rd, stderr_wr = IO.pipe
        Process.spawn(env, hook_file, :out => stdout_wr, :err => stderr_wr, :unsetenv_others => true)
        Process.wait
        exit_status = $?.exitstatus
        stdout_wr.close
        stderr_wr.close
        result = stdout_rd.read
        error_output = stderr_rd.read

        logger.info("Hook #{hook} for job #{job_template_name}: #{result}")

        unless exit_status == 0
          exception_message = "Hook #{hook} for #{job_template_name} failed "
          exception_message += "(exit: #{exit_status}) "
          exception_message += " stderr: #{error_output}, stdout: #{result}"
          logger.info(exception_message)

          raise Bosh::Agent::MessageHandlerError, exception_message
        end
        result
      end

      def create_symlink(src, dst)
        # FileUtils doesn have 'no-deference' for links - causing ln_sf to
        # attempt to create target link in dst rather than to overwrite it.
        # BROKEN: FileUtils.ln_sf(src, dst)
        out = %x(ln -nsf #{src} #{dst} 2>&1)
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError,
                "Failed to link '#{src}' to '#{dst}': #{out}"
        end
      end

      # Poor mans idempotency
      def update_file(data, path)
        name = File.basename(path)
        dir = File.dirname(path)

        if_tmp_file = Tempfile.new(name, dir)
        if_tmp_file.write(data)
        if_tmp_file.flush

        old = nil
        begin
          old = Digest::SHA1.file(path).hexdigest
        rescue Errno::ENOENT
          logger.debug("missing file: #{path}")
        end
        new = Digest::SHA1.file(if_tmp_file.path).hexdigest

        updated = false
        unless old == new
          FileUtils.cp(if_tmp_file.path, path)
          updated = true
        end
        updated
      ensure
        if if_tmp_file
           if_tmp_file.close
           FileUtils.rm_rf(if_tmp_file.path)
        end
      end

      def get_network_info
        sigar = SigarBox.create_sigar
        net_info = sigar.net_info
        ifconfig = sigar.net_interface_config(net_info.default_gateway_interface)

        properties = {}
        properties["ip"] = ifconfig.address
        properties["netmask"] = ifconfig.netmask
        properties["gateway"] = net_info.default_gateway
        properties
      end

    end
  end
end
