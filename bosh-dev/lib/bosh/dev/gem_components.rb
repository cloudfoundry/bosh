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

      each do |component|
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
       bosh-director
       bosh-director-core
       bosh-monitor
       bosh-release
       simple_blobstore_server
      ].each(&block)
    end

    def components
      return @components if @components

      @components = map { |component| GemComponent.new(component, @gem_version.version) }
    end

    def has_db?(component)
      %w(bosh-director bosh-registry).include?(component)
    end

    private

    def root
      GemComponent::ROOT
    end

    def stage_with_dependencies
      FileUtils.rm_rf 'pkg'

      components.each { |component| component.update_version }
      components.each { |component| component.build_release_gem }

      FileUtils.mkdir_p "/tmp/all_the_gems/#{Process.pid}"
      Rake::FileUtilsExt.sh "cp #{root}/pkg/gems/*.gem /tmp/all_the_gems/#{Process.pid}"
      Rake::FileUtilsExt.sh "cp #{root}/vendor/cache/*.gem /tmp/all_the_gems/#{Process.pid}"
    end

    def finalize_release_directory(component)
      dirname = "#{root}/release/src/bosh/#{component}"

      FileUtils.rm_rf dirname
      FileUtils.mkdir_p dirname
      gemfile_lock_path = File.join(root, 'Gemfile.lock')
      lockfile = Bundler::LockfileParser.new(File.read(gemfile_lock_path))
      Dir.chdir dirname do
        Bundler::Resolver.resolve(
          Bundler.definition.send(:expand_dependencies, Bundler.definition.dependencies.select { |d| d.name == component }),
          Bundler.definition.index,
          {},
          lockfile.specs
        ).each do |spec|
          Rake::FileUtilsExt.sh "cp /tmp/all_the_gems/#{Process.pid}/#{spec.name}-*.gem ."
          Rake::FileUtilsExt.sh "cp /tmp/all_the_gems/#{Process.pid}/pg*.gem ." if has_db?(component)
          Rake::FileUtilsExt.sh "cp /tmp/all_the_gems/#{Process.pid}/mysql*.gem ." if has_db?(component)
        end
      end
    end
  end
end
