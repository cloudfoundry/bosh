module Bosh::Dev::Artifact
  class Info < Struct.new(:name, :rev, :darwin_sha256, :linux_sha256, :bucket_name)
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

  class Installer
    attr_reader :info, :install_dir, :executable_name

    def initialize(info, install_dir, executable_name)
      @info = info
      @install_dir = install_dir
      @executable_name = executable_name
    end

    def install
      FileUtils.mkdir_p(install_dir)

      downloaded_file_path = download

      FileUtils.copy(downloaded_file_path, executable_path)
      FileUtils.remove(downloaded_file_path, :force => true)
      File.chmod(0700, executable_path)
    end

    def executable_path
      repo_root = File.expand_path('../../../../', File.dirname(__FILE__))

      File.expand_path(File.join(install_dir, executable_name), repo_root)
    end

    private

    def download
      destination_path = File.join(install_dir, info.file_name_to_download)

      unless File.exist?(destination_path)
        retryable.retryer do
          `#{File.dirname(__FILE__)}/sandbox/services/install_binary.sh #{info.file_name_to_download} #{destination_path} #{info.sha256} #{info.bucket_name}`
          $? == 0
        end
      end
      destination_path
    end

    def retryable
      Bosh::Retryable.new({tries: 6})
    end
  end
end
