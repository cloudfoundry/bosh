require 'common/retryable'

module Bosh::Dev
  class LegacyAgentManager
    S3_BUCKET_BASE_URL = 'https://s3.amazonaws.com/bosh-dependencies/legacy-agents'

    # When testing with a legacy agent, it should be compiled (for both Darwin and Linux) and uploaded to the S3 bucket.
    # For clarity, the file name should contain a description of the agent's purpose and the agent's git commit hash of
    # when it was built.
    #
    # To use, you must specify the cloud property "legacy_agent_path" and use the method "get_legacy_agent_path(agent_name)"
    LEGACY_AGENTS_LIST = [
      'no-upload-blob-action-e82bdd1c'
    ]

    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'integration-legacy-agents')

    def self.install
      FileUtils.mkdir_p(INSTALL_DIR)

      LEGACY_AGENTS_LIST.each do |agent_name|
        executable_file_path = generate_executable_full_path(agent_name)
        unless File.exist? executable_file_path
          downloaded_file_path = download(agent_name)
          FileUtils.copy(downloaded_file_path, executable_file_path)
          FileUtils.remove(downloaded_file_path, :force => true)
        end
        File.chmod(0777, executable_file_path)
      end
    end

    def self.generate_executable_full_path(agent_name)
      raise "Unable to find legacy agent with name #{agent_name}" unless LEGACY_AGENTS_LIST.include? agent_name
      File.expand_path(File.join(INSTALL_DIR, agent_name), REPO_ROOT)
    end

    private

    def self.download(agent_name)
      file_to_download = self.generate_file_name_to_download(agent_name)
      downloaded_file_full_path = File.join(INSTALL_DIR, file_to_download)

      unless File.exist?(downloaded_file_full_path)
        retryable.retryer do
          `curl --output #{downloaded_file_full_path} -L #{S3_BUCKET_BASE_URL}/#{file_to_download}`
          $? == 0
        end
      end
      downloaded_file_full_path
    end

    def self.retryable
      Bosh::Retryable.new({tries: 6})
    end

    def self.generate_file_name_to_download(agent_name)
      if RUBY_PLATFORM =~ /darwin/
        "agent-#{agent_name}-darwin-amd64"
      else
        "agent-#{agent_name}-linux-amd64"
      end
    end
  end
end
