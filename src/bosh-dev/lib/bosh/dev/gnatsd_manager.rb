require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '0.9.6-bosh.1'
    DARWIN_SHA256 = 'daed34467ca9e9a176c12e45089d860d5a28790c0899b5e71d29653aa72db843'
    LINUX_SHA256 = '6490559096960bf408c40f129a710a4960deb5a0c05477c541ea33d016069726'
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
