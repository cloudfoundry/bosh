require 'bosh/dev/bosh_cli_session'
require 'cli'
require 'yaml'

module Bosh::Dev
  class DirectorClient
    def initialize(options = {})
        @uri = options.fetch(:uri)
        @username = options.fetch(:username)
        @password = options.fetch(:password)
        @cli = BoshCliSession.new
        @director_handle = Bosh::Cli::Client::Director.new(uri, username, password)
    end

    def upload_stemcell(stemcell_archive)
      target_and_login!
      unless has_stemcell?(stemcell_archive.name, stemcell_archive.version)
        cmd = "upload stemcell #{stemcell_archive.path}"
        cli.run_bosh(cmd, debug_on_fail: true)
      end
    end

    def upload_release(release_path)
      target_and_login!
      cli.run_bosh("upload release #{release_path} --skip-if-exists", debug_on_fail: true)
    end

    def deploy(manifest_path)
      target_and_login!
      fix_uuid_in_manifest(manifest_path)
      cli.run_bosh("deployment #{manifest_path}")
      cli.run_bosh('deploy', debug_on_fail: true)
    end

    private

    attr_reader :uri, :username, :password, :cli, :director_handle

    def fix_uuid_in_manifest(manifest_path)
      manifest = YAML.load_file(manifest_path)
      manifest['director_uuid'] = director_handle.uuid
      File.open(manifest_path, 'w') { |f| f.write manifest.to_yaml }
    end

    def target_and_login!
      cli.run_bosh("target #{uri}", retryable: Bosh::Retryable.new(tries: 3, on: [RuntimeError]))
      cli.run_bosh("login #{username} #{password}")
    end

    def has_stemcell?(name, version)
      director_handle.list_stemcells.any? do |stemcell|
        stemcell['name'] == name && stemcell['version'] == version
      end
    end
  end
end
