module Bosh
  module Dev
    RELEASE_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    RELEASE_SRC_DIR = File.join(RELEASE_ROOT, 'src')
    ASSETS_DIR = File.join(RELEASE_ROOT, 'src', 'bosh-dev', 'assets', 'sandbox')
  end
end
