require 'common/retryable'
require_relative './artifact'

module Bosh::Dev
  class LegacyAgentManager
    # When testing with a legacy agent, it should be compiled (for both Darwin and Linux) and uploaded to the S3 bucket.
    # For clarity, the file name should contain a description of the agent's purpose and the agent's git commit hash of
    # when it was built.
    #
    # To use, you must specify the cloud property "legacy_agent_path" and use the method "get_legacy_agent_path(agent_name)"

    BUCKET_NAME = 'bosh-dependencies/legacy-agents'

    LEGACY_AGENTS_LIST = [
      Artifact::Info.new(
        'agent',
        'no-upload-blob-action-e82bdd1c',
        'b791ca6d4841478dcf25bfca91c96dc7b1cc72b719f4488c190d93ca33386fa9', # darwin
        '2a6f42496f1eed4b88871825511af97e9c6c691ab2402c13ea43748dd2873fa4', # linux
        BUCKET_NAME
      ),
      Artifact::Info.new(
        'agent',
        'upload-blob-action-error-file-not-found',
        'd380e1b780d86dc885ebd4dbec920d31b9f6288a34b8a083324fd6659931ab0e', # darwin
        '20d2d4c5812a0ae4a54623b5d93ccf04e8106dea47e546bbd774e8bb2730bbf1', # linux
        BUCKET_NAME
      ),
      Artifact::Info.new(
        'agent',
        'before-info-endpoint-20170719',
        'c5e115ba3197b1aca3c311cebe94aee8e6ef7f1523770af6879484de773e470e', # darwin
        '60f3364e828ba1a49532aa97163a4053f0fbf6aa679509cbd0d5dabf412bbf37', # linux
        BUCKET_NAME
      )
    ]


    REPO_ROOT = File.expand_path('../../../../', File.dirname(__FILE__))
    INSTALL_DIR = File.join('tmp', 'integration-legacy-agents')

    INSTALLERS = Hash[
      LEGACY_AGENTS_LIST.map do |legacy_agent_info|
        [legacy_agent_info.rev, Artifact::Installer.new(legacy_agent_info, INSTALL_DIR, legacy_agent_info.rev)]
      end
    ]

    def self.install
      INSTALLERS.each_value &:install
    end

    def self.generate_executable_full_path(agent_name)
      raise "Unable to find legacy agent with name #{agent_name}" unless INSTALLERS.has_key? agent_name

      INSTALLERS[agent_name].executable_path
    end
  end
end
