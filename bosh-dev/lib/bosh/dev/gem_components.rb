require 'rake'
require 'bosh/dev/gem_component'
require 'bosh/dev/gem_version'

module Bosh::Dev
  class GemComponents
    include Enumerable

    def initialize(build_number)
      @gem_version = GemVersion.new(build_number)
    end

    def build_release_gems
      FileUtils.mkdir_p build_dir

      stage_with_dependencies

      components.each do |component|
        finalize_release_directory(component)
      end

      FileUtils.rm_rf "/tmp/all_the_gems/#{Process.pid}"
    end

    def each(&block)
      %w(
        agent_client
        blobstore_client
        bosh-core
        bosh-stemcell
        bosh-template
        bosh_cli
        bosh_cli_plugin_aws
        bosh_cli_plugin_micro
        bosh_common
        bosh_cpi
        bosh-registry
        bosh-director
        bosh-director-core
        bosh-monitor
        bosh-release
        simple_blobstore_server
      ).each(&block)
    end

    def components
      @components ||= map { |component| GemComponent.new(component, @gem_version.version) }
    end

    private

    def has_db?(component_name)
      %w(bosh-director bosh-registry).include?(component_name)
    end

    def uses_bundler?(component_name)
      %w(bosh-director bosh-monitor bosh-registry).include?(component_name)
    end

    def root
      GemComponent::ROOT
    end

    def stage_with_dependencies
      FileUtils.rm_rf 'pkg'
      FileUtils.mkdir_p stage_dir

      components.each { |component| component.update_version }
      components.each { |component| component.build_gem(stage_dir) }

      Rake::FileUtilsExt.sh "cp #{root}/pkg/gems/*.gem #{build_dir}"
      Rake::FileUtilsExt.sh "cp #{root}/vendor/cache/*.gem #{build_dir}"
    end

    def stage_dir
      "#{root}/pkg/gems/"
    end

    def finalize_release_directory(component)
      dirname = "#{root}/release/src/bosh/#{component.name}"
      if uses_bundler?(component.name)
        dirname = File.join(dirname, 'vendor/cache')
      end

      FileUtils.rm_rf dirname
      FileUtils.mkdir_p dirname

      component.dependencies.each do |dependency|
        Rake::FileUtilsExt.sh "cp #{build_dir}/#{dependency.name}-*.gem #{dirname}"
      end

      if has_db?(component.name)
        Rake::FileUtilsExt.sh "cp #{build_dir}/pg*.gem #{dirname}"
        Rake::FileUtilsExt.sh "cp #{build_dir}/mysql*.gem #{dirname}"
      end
    end

    def build_dir
      @build_dir ||= "/tmp/all_the_gems/#{Process.pid}"
    end
  end
end
