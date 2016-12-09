require 'common/retryable'

module Bosh::Dev
  class LegacyAgentManager
    S3_BUCKET_BASE_URL = 'https://s3.amazonaws.com/bosh-dependencies/legacy-agents'

    class LegacyAgentInfo < Struct.new(:agent_name_rev, :darwin_sha256, :linux_sha256)
      def sha256
        darwin? ? darwin_sha256 : linux_sha256
      end

      def platform
        darwin? ? 'darwin' : 'linux'
      end

      def file_name_to_download
        "agent-#{agent_name_rev}-#{platform}-amd64"
      end

      private

      def darwin?
        RUBY_PLATFORM =~ /darwin/
      end
    end

    # When testing with a legacy agent, it should be compiled (for both Darwin and Linux) and uploaded to the S3 bucket.
    # For clarity, the file name should contain a description of the agent's purpose and the agent's git commit hash of
    # when it was built.
    #
    # To use, you must specify the cloud property "legacy_agent_path" and use the method "get_legacy_agent_path(agent_name)"
    LEGACY_AGENTS_LIST = [
      LegacyAgentInfo.new(
        'no-upload-blob-action-e82bdd1c',
        'b791ca6d4841478dcf25bfca91c96dc7b1cc72b719f4488c190d93ca33386fa9', # darwin
        '2a6f42496f1eed4b88871825511af97e9c6c691ab2402c13ea43748dd2873fa4' # linux
      )
    ]

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'integration-legacy-agents')

    def self.install
      FileUtils.mkdir_p(INSTALL_DIR)

      LEGACY_AGENTS_LIST.each do |legacy_agent_info|
        executable_file_path = generate_executable_full_path(legacy_agent_info.agent_name_rev)
        downloaded_file_path = download(legacy_agent_info)
        FileUtils.copy(downloaded_file_path, executable_file_path)
        FileUtils.remove(downloaded_file_path, :force => true)
        File.chmod(0700, executable_file_path)
      end
    end

    def self.generate_executable_full_path(agent_name)
      raise "Unable to find legacy agent with name #{agent_name}" unless LEGACY_AGENTS_LIST.map(&:agent_name_rev).include? agent_name
      File.expand_path(File.join(INSTALL_DIR, agent_name), REPO_ROOT)
    end

    private

    def self.download(agent_info)
      destination_path = File.join(INSTALL_DIR, agent_info.file_name_to_download)

      unless File.exist?(destination_path)
        retryable.retryer do
          `#{File.dirname(__FILE__)}/sandbox/services/install_binary.sh #{agent_info.file_name_to_download} #{destination_path} #{agent_info.sha256} bosh-dependencies/legacy-agents`
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
