require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '0.9.6-bosh.2'
    DARWIN_SHA256 = '14eafe9f708a1cce0f03c134f25c1e6fdd41ae0b007d560f23a9a7a2c23bf91c'
    LINUX_SHA256 = '672d952724c3c7ad60a61202831b6e254c971b19ee20ea0d859af0ef94803623'
    BUCKET_NAME = 'bosh-nats-tls'

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
