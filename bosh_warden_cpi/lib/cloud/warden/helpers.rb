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
      Bosh::Exec.sh("sudo -n #{cmd}", :yield => :on_false) do |result|
        yield result if block_given?
      end
    end

    def sh(cmd)
      logger.info "run '#{cmd}'"
      Bosh::Exec.sh("#{cmd}", :yield => :on_false) do |result|
        yield result if block_given?
      end
    end

  end
end
