require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '0.9.6-bosh.6'
    DARWIN_SHA256 = '13b9ffac19e0a733f8e7e07fcd34d8738a9942d29ce5776c396adc701e29967a'
    LINUX_SHA256 = '68afe5eaad377b336f9c58511be6de10d181f04ffddd8c3522c43d856a7e760b'
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
