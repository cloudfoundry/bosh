require 'common/retryable'
require_relative './install_info'

module Bosh::Dev
  class GnatsdManager
    VERSION = '0.9.6-bosh.1'
    DARWIN_SHA256 = 'daed34467ca9e9a176c12e45089d860d5a28790c0899b5e71d29653aa72db843'
    LINUX_SHA256 = '6490559096960bf408c40f129a710a4960deb5a0c05477c541ea33d016069726'
    BUCKET = 'bosh-nats-tls'

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'gnatsd')
    EXECUTABLE_NAME = 'gnatsd'

    class GnatsdInfo < Struct.new(:name, :rev, :darwin_sha256, :linux_sha256)
      def sha256
        darwin? ? darwin_sha256 : linux_sha256
      end

      def platform
        darwin? ? 'darwin' : 'linux'
      end

      def file_name_to_download
        "#{name}-#{rev}-#{platform}-amd64"
      end

      private

      def darwin?
        RUBY_PLATFORM =~ /darwin/
      end
    end

    def self.install
      FileUtils.mkdir_p(INSTALL_DIR)

      gnatsd_info = InstallInfo.new('gnatsd', VERSION, DARWIN_SHA256, LINUX_SHA256)

      downloaded_file_path = download(gnatsd_info)

      FileUtils.copy(downloaded_file_path, executable_path)
      FileUtils.remove(downloaded_file_path, :force => true)
      File.chmod(0700, executable_path)
    end

    def self.executable_path(gnatsd_name=EXECUTABLE_NAME)
      File.expand_path(File.join(INSTALL_DIR, gnatsd_name), REPO_ROOT)
    end

    private

    def self.download(gnatsd_info)
      destination_path = File.join(INSTALL_DIR, gnatsd_info.file_name_to_download)

      unless File.exist?(destination_path)
        retryable.retryer do
          `#{File.dirname(__FILE__)}/sandbox/services/install_binary.sh #{gnatsd_info.file_name_to_download} #{destination_path} #{gnatsd_info.sha256} #{BUCKET}`
          $? == 0
        end
      end
      destination_path
    end

    def self.retryable
      Bosh::Retryable.new({tries: 6})
    end
  end
end
