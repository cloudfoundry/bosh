require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '0.9.6-bosh.12'
    DARWIN_SHA256 = '4880812fc854e8c7691f2fa26d74cdab278e223267fa2c70204613a906ffaa1a'
    LINUX_SHA256 = 'e42777ce2da188a0f7bfb07a782c40275b8144de718b40253481e03169b05066'
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
