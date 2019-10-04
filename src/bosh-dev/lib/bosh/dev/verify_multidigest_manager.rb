require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class VerifyMultidigestManager
    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'verify-multidigest')
    BUCKET_NAME = 'verify-multidigest'.freeze

    VERSION = '0.0.156'.freeze
    DARWIN_SHA256 = '4450a58db4c3df9a522299525ab70eaf2aee94f74fc2404bc28dea1068c094d6'.freeze
    LINUX_SHA256 = 'f72a33761540d010c136d020038e764d04ddc9a1ee71ffd2367304f18ba550d3'.freeze

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
