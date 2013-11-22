require 'rake'

module Bosh::Dev
  class BoshRelease
    def self.build
      new(BoshCliSession.new)
    end

    def initialize(cli_session)
      @cli_session = cli_session
    end

    def tarball_path
      Dir.chdir('release') do
        output = @cli_session.run_bosh('create release --force --with-tarball')
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end
    end
  end
end
