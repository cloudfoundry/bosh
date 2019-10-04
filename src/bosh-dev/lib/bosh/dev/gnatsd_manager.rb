require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class GnatsdManager
    VERSION = '1.3.0-bosh.10'.freeze
    DARWIN_SHA256 = 'fac87b6b9b46830551f32f22930a61e2162edf025304f0f2ce7282b4350003f7'.freeze
    LINUX_SHA256 = 'e5362a7c88ed92d4f4263b1b725e901fe29da220c3548e37570793776b5f6d51'.freeze
    BUCKET_NAME = 'bosh-gnatsd'.freeze

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'gnatsd')
    EXECUTABLE_NAME = 'gnatsd'.freeze

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
