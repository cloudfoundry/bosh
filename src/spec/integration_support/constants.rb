module IntegrationSupport
  module Constants
    BOSH_REPO_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
    BOSH_REPO_SRC_DIR = File.join(BOSH_REPO_ROOT, 'src')

    SANDBOX_ASSETS_DIR = File.join(BOSH_REPO_SRC_DIR, 'spec', 'assets', 'sandbox')
    SANDBOX_CERTS_DIR = File.join(SANDBOX_ASSETS_DIR, 'ca', 'certs')
  end
end
