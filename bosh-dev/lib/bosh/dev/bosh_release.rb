require 'rake'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class ReleaseCreator
    def initialize(cli_session)
      @cli_session = cli_session
    end

    def create(options)
      is_final = !!options[:final]

      Dir.chdir('release') do
        output = @cli_session.run_bosh("create release #{'--final ' if is_final}--with-tarball")
        output.scan(/Release tarball\s+\(.+\):\s+(.+)$/).first.first
      end
    end
  end

  class BoshRelease
    def self.build
      bosh_cli_session = BoshCliSession.new
      release_creator = ReleaseCreator.new(bosh_cli_session)
      new(release_creator)
    end

    def initialize(release_creator)
      @release_creator = release_creator
    end

    def tarball_path
      @release_creator.create({})
      @release_creator.create(final: true)
    end
  end
end
