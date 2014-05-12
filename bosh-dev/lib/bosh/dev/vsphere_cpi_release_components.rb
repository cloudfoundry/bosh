require 'rake'
require 'bosh/dev/gem_component'
require 'cloud/vsphere/version'
require 'bosh/dev/gem_version'

module Bosh::Dev
  class VsphereCpiReleaseComponents

    def initialize
      @gems_to_build = %w(bosh_common bosh_cpi bosh_vsphere_cpi)
    end

    def build_release_gems
      FileUtils.mkdir_p build_dir

      components.each do |component|
        component.build_gem(build_dir)
        build_dependencies(component)
      end
    end

    private

    def build_dependencies(component)
      release_src_dir = "#{root}/vsphere-cpi-release/src/bosh_vsphere_cpi"

      FileUtils.rm_rf(release_src_dir)
      FileUtils.mkdir_p(release_src_dir)

      Dir.chdir release_src_dir do
        component.dependencies.each do |dependency|
          if @gems_to_build.include?(dependency.name)
            Rake::FileUtilsExt.sh "cp #{build_dir}/#{dependency.name}-*.gem ."
          else
            Rake::FileUtilsExt.sh "cp #{vendored_gem(dependency.name, dependency.version)} ."
          end
        end
      end
    end

    def components
      @components ||= @gems_to_build.map { |component| GemComponent.new(component, gem_version) }
    end

    def gem_version
      Bosh::Clouds::VSphere::VERSION
    end

    def build_dir
      @build_dir ||= "/tmp/all_the_gems/#{Process.pid}"
    end

    def vendored_gem(gem_name, gem_version)
      "#{root}/vendor/cache/#{gem_name}-#{gem_version}.gem"
    end

    def root
      GemComponent::ROOT
    end
  end
end
