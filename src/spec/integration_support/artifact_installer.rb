module IntegrationSupport

  class ArtifactInstaller
    INSTALL_BINARY_SCRIPT = File.expand_path(File.join(File.dirname(__FILE__), 'artifact_installer_install_binary.sh'))
    attr_reader :info, :install_dir, :executable_name

    def initialize(install_dir, executable_name, options)
      @install_dir = install_dir
      @executable_name = executable_name
      @info = Info.new(executable_name,
                       options[:version],
                       options[:darwin_sha256],
                       options[:linux_sha256],
                       options[:bucket_name])
    end

    def install
      FileUtils.mkdir_p(install_dir)

      downloaded_file_path = download

      FileUtils.copy(downloaded_file_path, executable_path)
      FileUtils.remove(downloaded_file_path, :force => true)
      File.chmod(0700, executable_path)
    end

    def executable_path
      File.join(Bosh::Dev::RELEASE_SRC_DIR, install_dir, executable_name)
    end

    private

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

    def download
      destination_path = File.join(install_dir, info.file_name_to_download)

      unless File.exist?(destination_path)
        retryable.retryer do
          `#{INSTALL_BINARY_SCRIPT} #{info.file_name_to_download} #{destination_path} #{info.sha256} #{info.bucket_name}`
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
