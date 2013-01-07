module Bosh::WardenCloud

  module Helpers

    def cloud_error(message)
      @logger.error(message) if @logger
      raise Bosh::Clouds::CloudError, message
    end

    def uuid(klass=nil)
      id = SecureRandom.uuid

      if klass
        id = "%s-%s" % [klass, id]
      end

      id
    end


    def sudo(cmd)
      logger.info "run 'sudo -n #{cmd}'"
      Bosh::Exec.sh "sudo -n #{cmd}"
    end

    def sh(cmd)
      logger.info "run '#{cmd}'"
      Bosh::Exec.sh "#{cmd}"
    end

    ##
    # This method generates a script that is run inside a container, to get an
    # available device path.
    #
    # This is hacky. The attached device is already formatted. In order to trick
    # bosh agent not to format the disk again, we touch an empty device file and
    # mknod the real partition file that is already formatted. Bosh agent will
    # mount skip the format process and directly mount the partition file.
    #
    # e.g.
    # Device file is like /dev/sda
    # Partition file is like /dev/sda1
    def attach_script(device_number, device_prefix)
      script = <<-EOF
for i in a b c d e f g h; do (stat #{device_prefix}${i} > /dev/null 2>&1) || break; done
touch #{device_prefix}${i}
mknod #{device_prefix}${i}1 b 7 #{device_number} > /dev/null 2>&1 && echo "#{device_prefix}${i}"
      EOF
    end

    def partition_path(device_path)
      "#{device_path}1"
    end

    def process_user
      Etc.getpwuid(Process.uid).name
    end

  end
end
