require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class VerifyMultidigestManager

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'verify-multidigest')
    BUCKET_NAME = 'verify-multidigest'

    VERSION = '0.0.29'
    DARWIN_SHA256 = 'cb5c51d6912f829d482e0a52aeef0286c646f48c07bd2aecfe3969ddcb44c6dc'
    LINUX_SHA256 = '0a4f79232cf7752712c8825624ef78da6de5dbc56c809324c24d614fbb9e3990'

    INFO = Artifact::Info.new('verify-multidigest', VERSION, DARWIN_SHA256, LINUX_SHA256, BUCKET_NAME)
    INSTALLER = Artifact::Installer.new(INFO, INSTALL_DIR, 'verify-multidigest')

    def self.install
      INSTALLER.install
    end

    def self.executable_path
      INSTALLER.executable_path
    end
  end
end
