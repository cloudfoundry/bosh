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

  end
end
