require 'cli'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class DirectorClient
    def initialize(options = {})
        @uri = options.fetch(:uri)
        @username = options.fetch(:username)
        @password = options.fetch(:password)
        @cli = BoshCliSession.new
    end

    def stemcells
      director_handle.list_stemcells
    end

    def has_stemcell?(name, version)
      stemcells.any? do |stemcell|
        stemcell['name'] == name && stemcell['version'] == version
      end
    end

    def upload_stemcell(stemcell_archive)
      cli.run_bosh("target #{uri}")
      cli.run_bosh("login #{username} #{password}")
      cli.run_bosh("upload stemcell #{stemcell_archive.path}", debug_on_fail: true)  unless has_stemcell?(stemcell_archive.name, stemcell_archive.version)
    end

    def upload_release(release_path)
      cli.run_bosh("upload release #{release_path} --rebase", debug_on_fail: true)
    end

    def deploy(manifest_path)
      cli.run_bosh("deployment #{manifest_path}")
      cli.run_bosh('deploy', debug_on_fail: true)
    end

    private

    attr_reader :uri, :username, :password, :cli

    def director_handle
      @director_handle ||= Bosh::Cli::Director.new(uri, username, password)
    end
  end
end
