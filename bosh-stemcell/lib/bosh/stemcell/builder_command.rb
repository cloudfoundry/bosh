require 'fileutils'

require 'bosh/core/shell'
require 'bosh/stemcell/builder_options'
require 'bosh/stemcell/disk_image'
require 'bosh/stemcell/definition'
require 'bosh/stemcell/stage_collection'
require 'bosh/stemcell/stage_runner'
require 'bosh/stemcell/builder_command_helper'

require 'forwardable'

module Bosh::Stemcell
  class BuilderCommand
    extend Forwardable

    STEMCELL_BUILDER_SOURCE_DIR = File.join(File.expand_path('../../../../..', __FILE__), 'stemcell_builder')
    STEMCELL_SPECS_DIR = File.expand_path('../../..', File.dirname(__FILE__))

    def initialize(env, definition, version, release_tarball_path)
      @environment = env
      @definition = definition
      @helper = BuilderCommandHelper.new(env, definition, version, release_tarball_path,
                                         STEMCELL_BUILDER_SOURCE_DIR, STEMCELL_SPECS_DIR)
      @shell = Bosh::Core::Shell.new
    end

    def build
      prepare_build

      stage_collection = StageCollection.new(definition)
      stage_runner = StageRunner.new(
        build_path: build_path,
        command_env: command_env,
        settings_file: settings_path,
        work_path: work_root
      )

      operating_system_stages = stage_collection.operating_system_stages
      agent_stages = stage_collection.agent_stages
      infrastructure_stages = stage_collection.infrastructure_stages

      all_stages = operating_system_stages + agent_stages + infrastructure_stages

      stage_runner.configure_and_apply(all_stages)
      shell.run(helper.rspec_command)

      helper.stemcell_file
    end

    def chroot_dir
      helper.chroot_dir
    end

    private

    def_delegators(
      :@definition,
      :infrastructure,
      :operating_system,
      :agent,
    )

    attr_reader(
      :shell,
      :environment,
      :definition,
      :helper,
      :build_path,
      :settings_path,
      :work_root,
    )


    def prepare_build
      helper.sanitize

      helper.prepare_build_root

      @build_path = helper.prepare_build_path

      helper.copy_stemcell_builder_to_build_path

      @work_root = helper.prepare_work_root

      @settings_path = helper.persist_settings_for_bash
    end

    def command_env
      "env #{hash_as_bash_env(proxy_settings_from_environment)}"
    end

    def proxy_settings_from_environment
      keep = %w(HTTP_PROXY NO_PROXY)

      environment.select { |k| keep.include?(k.upcase) }
    end

    def hash_as_bash_env(env)
      env.map { |k, v| "#{k}='#{v}'" }.join(' ')
    end
  end
end
