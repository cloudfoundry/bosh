require 'bosh/dev/sandbox/workspace'

class ClientSandbox
  class << self
    def base_dir
      File.join(Bosh::Dev::Sandbox::Workspace.dir, 'client-sandbox')
    end

    def home_dir
      File.join(base_dir, 'home')
    end

    def test_release_dir
      File.join(base_dir, 'test_release')
    end

    def manifests_dir
      File.join(base_dir, 'manifests')
    end

    def links_release_dir
      File.join(base_dir, 'links_release')
    end

    def multidisks_release_dir
      File.join(base_dir, 'multidisks_release')
    end

    def bosh_work_dir
      File.join(base_dir, 'bosh_work_dir')
    end

    def bosh_config
      File.join(base_dir, 'bosh_config.yml')
    end

    def blobstore_dir
      File.join(base_dir, 'release_blobstore')
    end
  end
end
