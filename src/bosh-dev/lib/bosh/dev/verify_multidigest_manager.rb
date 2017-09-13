require 'common/retryable'
require_relative './install_info'

module Bosh::Dev
  class VerifyMultidigestManager

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'verify-multidigest')

    def self.install
      FileUtils.mkdir_p(INSTALL_DIR)

      multidigest_info = InstallInfo.new('verify-multidigest', '0.0.29', 'cb5c51d6912f829d482e0a52aeef0286c646f48c07bd2aecfe3969ddcb44c6dc', '0a4f79232cf7752712c8825624ef78da6de5dbc56c809324c24d614fbb9e3990')
      executable_file_path = generate_executable_full_path('verify-multidigest')
      downloaded_file_path = download(multidigest_info)
      FileUtils.copy(downloaded_file_path, executable_file_path)
      FileUtils.remove(downloaded_file_path, :force => true)
      File.chmod(0700, executable_file_path)
    end

    def self.generate_executable_full_path(multidigest_name)
      File.expand_path(File.join(INSTALL_DIR, multidigest_name), REPO_ROOT)
    end

    private

    def self.download(multidigest_info)
      destination_path = File.join(INSTALL_DIR, multidigest_info.file_name_to_download)

      unless File.exist?(destination_path)
        retryable.retryer do
          `#{File.dirname(__FILE__)}/sandbox/services/install_binary.sh #{multidigest_info.file_name_to_download} #{destination_path} #{multidigest_info.sha256} verify-multidigest`
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
