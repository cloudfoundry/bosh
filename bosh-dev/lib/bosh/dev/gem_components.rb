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
      stage_with_dependencies

      components.each do |component|
        finalize_release_directory(component)
      end

      FileUtils.rm_rf "/tmp/all_the_gems/#{Process.pid}"
    end

    def each(&block)
      %w[
       agent_client
       blobstore_client
       bosh-core
       bosh-stemcell
       bosh_agent
       bosh_aws_cpi
       bosh_cli
       bosh_cli_plugin_aws
       bosh_cli_plugin_micro
       bosh_common
       bosh_cpi
       bosh_openstack_cpi
       bosh-registry
       bosh_vsphere_cpi
       bosh_warden_cpi
       bosh-director
       bosh-director-core
       bosh-monitor
       bosh-release
       simple_blobstore_server
      ].each(&block)
    end

    def components
      @components ||= map { |component| GemComponent.new(component, @gem_version.version) }
    end

    def has_db?(component_name)
      %w(bosh-director bosh-registry).include?(component_name)
    end

    private

    def root
      GemComponent::ROOT
    end

    def stage_with_dependencies
      FileUtils.rm_rf 'pkg'
      FileUtils.mkdir_p stage_dir

      components.each { |component| component.update_version }
      components.each { |component| component.build_gem(stage_dir) }

      FileUtils.mkdir_p "/tmp/all_the_gems/#{Process.pid}"
      Rake::FileUtilsExt.sh "cp #{root}/pkg/gems/*.gem #{build_dir}"
      Rake::FileUtilsExt.sh "cp #{root}/vendor/cache/*.gem #{build_dir}"
    end

    def stage_dir
      "#{root}/pkg/gems/"
    end

    def finalize_release_directory(component)
      dirname = "#{root}/release/src/bosh/#{component.name}"

      FileUtils.rm_rf dirname
      FileUtils.mkdir_p dirname

      Dir.chdir dirname do
        component.dependencies.each do |dependency|
          Rake::FileUtilsExt.sh "cp #{build_dir}/#{dependency.name}-*.gem ."
          Rake::FileUtilsExt.sh "cp #{build_dir}/pg*.gem ." if has_db?(component.name)
          Rake::FileUtilsExt.sh "cp #{build_dir}/mysql*.gem ." if has_db?(component.name)
        end
      end
    end

    def build_dir
      @build_dir ||= "/tmp/all_the_gems/#{Process.pid}"
    end
  end
end
