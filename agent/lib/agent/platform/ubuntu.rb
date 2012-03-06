
module Bosh::Agent
  class Platform::Ubuntu
    require 'agent/platform/ubuntu/logrotate'
    require 'agent/platform/ubuntu/password'

    def configure_disks(settings)
    end

    def update_logging(spec)
      Logrotate.new(spec).install
    end

    def update_passwords(settings)
      Password.new.update(settings)
    end

  end
end
