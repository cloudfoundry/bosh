require 'cli'
require 'yaml'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class DirectorClient
    def initialize(uri, username, password, bosh_cli_session)
      @uri = uri
      @username = username
      @password = password
      @bosh_cli_session = bosh_cli_session
      credentials = Bosh::Cli::Client::BasicCredentials.new(username, password)
      @director_handle = Bosh::Cli::Client::Director.new(uri, credentials)
    end

    def upload_stemcell(stemcell_archive)
      target_and_login!
      unless has_stemcell?(stemcell_archive.name, stemcell_archive.version)
        @bosh_cli_session.run_bosh("upload stemcell #{stemcell_archive.path}", debug_on_fail: true)
      end
    end

    def upload_release(release_path)
      target_and_login!
      @bosh_cli_session.run_bosh("upload release #{release_path} --skip-if-exists", debug_on_fail: true)
    end

    def deploy(manifest_path)
      target_and_login!
      fix_uuid_in_manifest(manifest_path)
      @bosh_cli_session.run_bosh("deployment #{manifest_path}")
      @bosh_cli_session.run_bosh('deploy', debug_on_fail: true)
      @bosh_cli_session.run_bosh('deployments')
    end

    def clean_up
      target_and_login!
      @bosh_cli_session.run_bosh('cleanup', debug_on_fail: true)
    end

    private

    def fix_uuid_in_manifest(manifest_path)
      manifest = YAML.load_file(manifest_path)
      if manifest['director_uuid'] != @director_handle.uuid
        manifest['director_uuid'] = @director_handle.uuid
        File.open(manifest_path, 'w') { |f| f.write manifest.to_yaml }
      end
    end

    def target_and_login!
      @bosh_cli_session.run_bosh("target #{@uri}", retryable: Bosh::Retryable.new(tries: 3, on: [RuntimeError]))
      @bosh_cli_session.run_bosh("login #{@username} #{@password}")
    end

    def has_stemcell?(name, version)
      @director_handle.list_stemcells.any? do |stemcell|
        stemcell['name'] == name && stemcell['version'] == version
      end
    end
  end
end
