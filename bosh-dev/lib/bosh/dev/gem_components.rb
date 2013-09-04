module Bosh::Dev
  class GemComponents
    include Enumerable

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

    def last_released_component(component, root, version)
      File.join(root, 'release', 'src', 'bosh', component, "#{component}-#{version}.gem")
    end

    def root
      @root ||= File.expand_path('../../../../../', __FILE__)
    end

    def version
      File.read("#{root}/BOSH_VERSION").strip
    end

    def update_version(component)
      glob = File.join(root, component, 'lib', '**', 'version.rb')

      version_file_path = Dir[glob].first
      file_contents = File.read(version_file_path)
      file_contents.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{version}'")

      File.open(version_file_path, 'w') { |f| f.write(file_contents) }
    end
  end
end
