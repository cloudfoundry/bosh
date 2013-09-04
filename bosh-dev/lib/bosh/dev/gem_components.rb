require 'rake'
require 'bosh/dev/gem_component'

module Bosh::Dev
  class GemComponents
    include Enumerable

    def build_release_gems
      stage_with_dependencies

      each do |component|
        finalize_release_directory(component)
      end

      FileUtils.rm_rf "/tmp/all_the_gems/#{Process.pid}"
    end

    def pre_stage_latest(component)
      FileUtils.mkdir_p 'pkg/gems'

      gem_component = GemComponent.new(component)
      gem_component.update_version

      gemspec = "#{component}.gemspec"
      if component_needs_update(component, root, version)
        Rake::FileUtilsExt.sh "cd #{component} && gem build #{gemspec} && mv #{component}-#{version}.gem #{root}/pkg/gems/"
      else
        Rake::FileUtilsExt.sh "cp '#{last_released_component(component, root, version)}' #{root}/pkg/gems/"
      end
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
       bosh_encryption
       bosh_openstack_cpi
       bosh_registry
       bosh_vsphere_cpi
       director
       health_monitor
       monit_api
       package_compiler
       ruby_vim_sdk
       simple_blobstore_server
      ].each(&block)
    end

    def has_db?(component)
      %w(director bosh_registry).include?(component)
    end

    def component_needs_update(component, root, version)
      Dir.chdir(File.join(root, component)) do
        gemspec_path = File.join(root, component, "#{component}.gemspec")
        gemspec = Gem::Specification.load(gemspec_path)
        files = gemspec.files + [gemspec_path]
        last_code_change_time = files.map { |file| File::Stat.new(file).mtime }.max
        gem_file_name = last_released_component(component, root, version)

        !File.exists?(gem_file_name) || last_code_change_time > File::Stat.new(gem_file_name).mtime
      end
    end
    alias_method :component_needing_update?, :component_needs_update

    private

    def last_released_component(component, root, version)
      File.join(root, 'release', 'src', 'bosh', component, "#{component}-#{version}.gem")
    end

    def root
      @root ||= File.expand_path('../../../../../', __FILE__)
    end

    def version
      File.read("#{root}/BOSH_VERSION").strip
    end

    def stage_with_dependencies
      FileUtils.rm_rf 'pkg'

      each do |component|
        pre_stage_latest(component)
      end

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
