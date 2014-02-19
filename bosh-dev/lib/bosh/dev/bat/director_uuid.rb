require 'bosh/dev'

module Bosh::Dev::Bat
  class DirectorUuid
    def initialize(cli_session)
      @cli_session = cli_session
    end

    def value
      @cli_session.run_bosh('status --uuid').strip
    end
  end
end
