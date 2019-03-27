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
        'before-registry-removal-20181001',
        'c600a02b73dd4f7661318cf8a5762b4550ff0646589e2a583cbff10417a16d93', # darwin
        '284d28423cd7fb9f9fed9fe7de4c569b520cc8b6380b987eb72d5d54e5dc995b', # linux
        BUCKET_NAME,
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
