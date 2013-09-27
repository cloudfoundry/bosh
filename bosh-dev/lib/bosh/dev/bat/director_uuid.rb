require 'bosh/dev'

module Bosh::Dev::Bat
  class DirectorUuid
    class UnknownUuidError < RuntimeError; end

    def initialize(cli_session)
      @cli_session = cli_session
    end

    def value
      status_output = @cli_session.run_bosh('status')

      matches = /UUID(\s)+(?<uuid>(\w+-)+\w+)/x.match(status_output)
      raise UnknownUuidError, status_output unless matches

      matches[:uuid]
    end
  end
end
