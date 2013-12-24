require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/release_creator'

module Bosh::Dev
  class BoshRelease
    def self.build
      bosh_cli_session = BoshCliSession.new
      release_creator = ReleaseCreator.new(bosh_cli_session)
      new(release_creator)
    end

    def initialize(release_creator)
      @release_creator = release_creator
    end

    def final_tarball_path
      @release_creator.create_final
    end

    def dev_tarball_path
      @release_creator.create_dev
    end
  end
end
