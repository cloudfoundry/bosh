module Bosh::Dev
  class ReleaseCreator
    def initialize(cli_session)
      @cli_session = cli_session
    end

    def create
      Dir.chdir('release') do
        @cli_session.run_bosh('create release --force --with-tarball')
        output = @cli_session.run_bosh('create release --force --final --with-tarball')
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end
    end
  end
end
