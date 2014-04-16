require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class MicroClient
    def initialize
      @cli = BoshCliSession.new
    end

    def deploy(manifest_path, stemcell_archive)
      Dir.chdir(File.dirname(manifest_path)) do
        @cli.run_bosh("micro deployment #{manifest_path}")
        @cli.run_bosh("micro deploy #{stemcell_archive.path} --update-if-exists")
      end
    end
  end
end
