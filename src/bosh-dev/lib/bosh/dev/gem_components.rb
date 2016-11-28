require 'rake'
require 'bosh/dev/gem_component'
require 'bosh/dev/gem_version'

module Bosh::Dev
  class GemComponents
    include Enumerable
    COMPONENTS = %w(
      blobstore_client
      bosh-core
      bosh-stemcell
      bosh-template
      bosh_cli
      bosh_common
      bosh_cpi
      bosh-registry
      bosh-director
      bosh-director-core
      bosh-monitor
    )

    def initialize(build_number)
      @gem_version = GemVersion.new(build_number)
    end

    def build_release_gems
      clean
      stage_components

      components.each do |component|
        finalize(component)
      end
      FileUtils.rm_rf build_dir
    end

    def each(&block)
      COMPONENTS.each(&block)
    end

    def components
      @components ||= map { |component| GemComponent.new(component, @gem_version.version) }
    end

    private

    def clean
      FileUtils.rm_rf tmp_dir
      FileUtils.mkdir_p build_dir

      FileUtils.rm_rf stage_dir
      FileUtils.mkdir_p stage_dir
    end

    def stage_components
      components.each { |component| component.update_version }
      components.each { |component| component.build_gem(stage_dir) }

      Rake::FileUtilsExt.sh "cp #{root}/pkg/gems/*.gem #{build_dir}"
      Rake::FileUtilsExt.sh "cp #{root}/vendor/cache/*.gem #{build_dir}"
    end

    def finalize(component)
      destination = "#{root}/release/src/bosh/#{component.name}"
      if uses_bundler?(component.name)
        destination = File.join(destination, 'vendor/cache')
      end

      FileUtils.rm_rf destination
      FileUtils.mkdir_p destination

      component.dependencies.each do |dependency|
        copy_component(dependency, destination)
      end

      if has_db?(component.name)
        Rake::FileUtilsExt.sh "cp #{build_dir}/pg*.gem #{destination}"
        Rake::FileUtilsExt.sh "cp #{build_dir}/mysql*.gem #{destination}"
      end
    end

    # enforces strict version.
    def copy_component(dependency, destination)
      FileUtils.cp "#{build_dir}/#{dependency.name}-#{dependency.version}.gem", "#{destination}"
    rescue Errno::ENOENT => e
      gemfile = e.message.sub(/^.+#{Regexp.escape(build_dir)}\//, '')
      gemparts = gemfile.split('-')
      version = gemparts.pop.sub(/\.gem$/, '')
      gemname = gemparts.join('-')
      puts
      puts "ERROR! #{gemfile} was not found."
      puts "Please run the following before rebuilding the release:"
      puts "- `gem uninstall #{gemname} --version #{version}`"
      exit 1
    end

    def root
      GemComponent::ROOT
    end

    def tmp_dir
      "/tmp/all_the_gems"
    end

    def build_dir
      @build_dir ||= File.join(tmp_dir, Process.pid.to_s)
    end

    def stage_dir
      "#{root}/pkg/gems/"
    end

    def has_db?(component_name)
      %w(bosh-director bosh-registry).include?(component_name)
    end

    def uses_bundler?(component_name)
      %w(bosh-director bosh-monitor bosh-registry).include?(component_name)
    end
  end
end
