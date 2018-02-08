require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '0.9.6-bosh.13'
    DARWIN_SHA256 = '4f30811155694ac057b269c9235629789d89296381d7e61c9adad345acdc6afa'
    LINUX_SHA256 = 'aed21d73b0155db2871e724e3f1ed033433e7ea2d814406b1451de53edc20d6d'
    BUCKET_NAME = 'bosh-gnatsd'

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'gnatsd')
    EXECUTABLE_NAME = 'gnatsd'

    INFO = Artifact::Info.new('gnatsd', VERSION, DARWIN_SHA256, LINUX_SHA256, BUCKET_NAME)
    INSTALLER = Artifact::Installer.new(INFO, INSTALL_DIR, 'gnatsd')

    def self.install
      INSTALLER.install
    end

    def self.executable_path
      INSTALLER.executable_path
    end
  end
end
