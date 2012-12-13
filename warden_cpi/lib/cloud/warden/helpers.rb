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
    # e.g.
    # Device path is like /dev/sda
    # Partition path is like /dev/sda1
    def attach_script(device_number, device_prefix)
      script = <<-EOF
for i in a b c d e f g h; do (stat #{device_prefix}${i}1 > /dev/null 2>&1) || break; done
mknod #{device_prefix}${i}1 b 7 #{device_number} > /dev/null 2>&1 && echo "#{device_prefix}${i}"
      EOF
    end

    def partition_path(device_path)
      "#{device_path}1"
    end

  end
end
