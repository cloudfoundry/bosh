require 'rake'
require 'bosh/dev/gem_component'
require 'cloud/vsphere/version'
require 'bosh/dev/gem_version'

module Bosh::Dev
  class VsphereCpiReleaseComponents

    def build_gems
      FileUtils.mkdir_p build_dir

      components.each do |component|
        gemspec = "#{component}.gemspec"

        Rake::FileUtilsExt.sh "cd #{component} && gem build #{gemspec} && mv #{dot_gem(component)} #{build_dir}"

        build_dependencies(component)
      end
    end

    private

    def build_dependencies(dep_name)
      release_src_dir = "#{root}/vsphere-cpi-release/src/bosh_vsphere_cpi/"

      FileUtils.rm_rf(release_src_dir)
      FileUtils.mkdir_p(release_src_dir)

      Dir.chdir release_src_dir do
        Bundler::Resolver.resolve(
          Bundler.definition.send(:expand_dependencies, Bundler.definition.dependencies.select { |d| d.name == dep_name }),
          Bundler.definition.index,
          {},
          lockfile.specs
        ).each do |spec|
          if components.include?(spec.name)
            Rake::FileUtilsExt.sh "cp #{build_dir}/#{spec.name}-*.gem ."
          else
            Rake::FileUtilsExt.sh "cp #{vendored_gem(spec.name, spec.version)} ."
          end
        end
      end
    end

    def components
      %w(bosh_common bosh_cpi bosh_vsphere_cpi)
    end

    def gem_version
      Bosh::Clouds::VSphere::VERSION
    end

    def dot_gem(gem_name)
      "#{gem_name}-#{gem_version}.gem"
    end

    def build_dir
      @build_dir ||= "/tmp/all_the_gems/#{Process.pid}"
    end

    def gemfile_lock_path
      File.join(root, 'Gemfile.lock')
    end

    def lockfile
      Bundler::LockfileParser.new(File.read(gemfile_lock_path))
    end

    def vendored_gem(gem_name, gem_version)
      "#{root}/vendor/cache/#{gem_name}-#{gem_version}.gem"
    end

    def root
      GemComponent::ROOT
    end
  end
end
