module Bosh::Dev
  class ReleaseCreator
    def initialize(cli_session)
      @cli_session = cli_session
    end

    def create_final
      Dir.chdir('release') do
        @cli_session.run_bosh('create release --force')

        release_version = ''
        unless ENV['BOSH_FINAL_RELEASE_VERSION'].nil?
          release_version = " --version #{ENV['BOSH_FINAL_RELEASE_VERSION']}"
        end

        output = @cli_session.run_bosh("create release --force --final --with-tarball#{release_version}")
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end
    end

    def create_dev
      Dir.chdir('release') do
        output = @cli_session.run_bosh('create release --force --with-tarball')
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end
    end
  end
end
