require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '1.3.0-bosh.2'.freeze
    DARWIN_SHA256 = 'd1ea29e83a26635cf2301b771c47ed30c332056a66931cec8f7091d7dd163401'.freeze
    LINUX_SHA256 = '528ebd92d5909535763e7c9439f9564403fd663c0f64e869d568187bb6823ea0'.freeze
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
