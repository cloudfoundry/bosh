
module Bosh::Agent
  class Platform::Ubuntu
    require 'agent/platform/ubuntu/logrotate'

    def update_logging(spec)
      Logrotate.new(spec).install
    end

  end
end
