module Bosh::WardenCloud

  module Helpers

    def cloud_error(error)
      unless error.instance_of? Bosh::Clouds::CloudError
        error = Bosh::Clouds::CloudError.new error
      end

      @logger.error(error.message) if @logger
      raise error
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

    def attach_script(device_number, device_prefix)
      script = <<-EOF
for i in `seq 256`; do (stat #{device_prefix}$i > /dev/null 2>&1) || break; done
mknod #{device_prefix}$i b 7 #{device_number} > /dev/null 2>&1 && echo "#{device_prefix}$i"
      EOF
    end

  end
end
