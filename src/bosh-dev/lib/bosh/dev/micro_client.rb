require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class MicroClient
    def initialize(bosh_cli_session)
      @bosh_cli_session = bosh_cli_session
    end

    def deploy(manifest_path, stemcell_archive)
      Dir.chdir(File.dirname(manifest_path)) do
        @bosh_cli_session.run_bosh("micro deployment #{manifest_path}")
        @bosh_cli_session.run_bosh("micro deploy #{stemcell_archive.path} --update-if-exists")
      end
    end
  end
end
