require 'fileutils'

require 'bosh/stemcell/infrastructure'

module Bosh::Dev
  class StemcellRakeMethods
    def initialize(environment = ENV.to_hash)
      @environment = environment
    end

    def bosh_micro_options(manifest, tarball)
      {
        bosh_micro_enabled: 'yes',
        bosh_micro_package_compiler_path: File.expand_path('../../../../../package_compiler', __FILE__),
        bosh_micro_manifest_yml_path: manifest,
        bosh_micro_release_tgz_path: tarball,
      }
    end

    # GIT CHANGES

    def changes_in_bosh_agent?
      gem_components_changed?('bosh_agent') || component_changed?('stemcell_builder')
    end

    def changes_in_microbosh?
      microbosh_components = COMPONENTS - %w(bosh_cli bosh_cli_plugin_aws bosh_cli_plugin_micro)
      components_changed = microbosh_components.reduce(false) do |changes, component|
        changes || gem_components_changed?(component)
      end
      components_changed || component_changed?('stemcell_builder')
    end

    def diff
      @diff ||= changed_components
    end

    def changed_components(new_commit_sha = ENV['GIT_COMMIT'], old_commit_sha = ENV['GIT_PREVIOUS_COMMIT'])
      repo = Rugged::Repository.new('.')
      old_trees = old_commit_sha ? repo.lookup(old_commit_sha).tree.to_a : []
      new_trees = repo.lookup(new_commit_sha || repo.head.target).tree.to_a
      (new_trees - old_trees).map { |entry| entry[:name] }
    end

    def component_changed?(path)
      diff.include?(path)
    end

    def gem_components_changed?(gem_name)
      gem = Gem::Specification.load(File.join(gem_name, "#{gem_name}.gemspec"))

      components =
        %w(Gemfile Gemfile.lock) + [gem_name] + gem.runtime_dependencies.map { |d| d.name }.select { |d| Dir.exists?(d) }

      components.reduce(false) do |changes, component|
        changes || component_changed?(component)
      end
    end

    # DEFAULT OPTIONS (DONE)

    def default_options(args)
      infrastructure = args.fetch(:infrastructure) do
        STDERR.puts 'Please specify target infrastructure (vsphere, aws, openstack)'
        exit 1
      end

      options = {
        'system_parameters_infrastructure' => infrastructure,
        'stemcell_name' => environment['STEMCELL_NAME'],
        'stemcell_infrastructure' => infrastructure,
        'stemcell_hypervisor' => hypervisor_for(infrastructure),
        'bosh_protocol_version' => Bosh::Agent::BOSH_PROTOCOL,
        'UBUNTU_ISO' => environment['UBUNTU_ISO'],
        'UBUNTU_MIRROR' => environment['UBUNTU_MIRROR'],
        'TW_LOCAL_PASSPHRASE' => environment['TW_LOCAL_PASSPHRASE'],
        'TW_SITE_PASSPHRASE' => environment['TW_SITE_PASSPHRASE'],
        'ruby_bin' => environment['RUBY_BIN'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']),
        'bosh_release_src_dir' => File.expand_path('../../../../../release/src/bosh', __FILE__),
        'bosh_agent_src_dir' => File.expand_path('../../../../../bosh_agent', __FILE__),
      }

      options = check_for_ovftool!(options) if infrastructure == 'vsphere'

      options.merge('image_create_disk_size' => default_disk_size_for(infrastructure, args))
    end

    # BUILDING

    def get_working_dir
      ENV['BUILD_PATH'] || "/var/tmp/bosh/bosh_agent-#{Bosh::Agent::VERSION}-#{$$}"
    end

    def env
      keep = %w{
      HTTP_PROXY
      http_proxy
      NO_PROXY
      no_proxy
      }

      format_env(ENV.select { |k| keep.include?(k) })
    end

    # Format a hash as an env command.
    def format_env(h)
      'env ' + h.map { |k, v| "#{k}='#{v}'" }.join(' ')
    end

    def build(spec, options)
      root = get_working_dir
      FileUtils.mkdir_p root
      puts "MADE ROOT: #{root}"
      puts "PWD: #{Dir.pwd}"

      build_path = File.join(root, 'build')

      FileUtils.rm_rf build_path
      FileUtils.mkdir_p build_path
      stemcell_build_dir = File.expand_path('../../../../../stemcell_builder', __FILE__)
      FileUtils.cp_r Dir.glob("#{stemcell_build_dir}/*"), build_path, preserve: true

      work_path = ENV['WORK_PATH'] || File.join(root, 'work')
      FileUtils.mkdir_p work_path

      # Apply options
      settings_dir = File.join(build_path, 'etc')
      settings_path = File.join(settings_dir, 'settings.bash')
      File.open(settings_path, 'a') do |f|
        f.printf("\n# %s\n\n", '=' * 20)
        options.each do |k, v|
          f.print "#{k}=#{v}\n"
        end
      end

      builder_path = File.join(build_path, 'bin', 'build_from_spec.sh')
      spec_path = File.join(build_path, 'spec', "#{spec}.spec")

      # Run builder
      STDOUT.puts "building in #{work_path}..."
      cmd = "sudo #{env} #{builder_path} #{work_path} #{spec_path} #{settings_path}"

      puts cmd
      system cmd
    end

    private

    attr_reader :environment

    def check_for_ovftool!(options)
      ovftool_path = environment.fetch('OVFTOOL') do
        raise 'Please set OVFTOOL to the path of `ovftool`.'
      end
      options.merge('image_vsphere_ovf_ovftool_path' => ovftool_path)
    end

    def default_disk_size_for(infrastructure, args)
      return args[:disk_size] if args[:disk_size]

      Bosh::Stemcell::Infrastructure.for(infrastructure).default_disk_size
    end

    def hypervisor_for(infrastructure)
      return environment['STEMCELL_HYPERVISOR'] if environment['STEMCELL_HYPERVISOR']

      begin
        Bosh::Stemcell::Infrastructure.for(infrastructure).hypervisor
      rescue ArgumentError
        raise "Unknown infrastructure: #{infrastructure}"
      end
    end
  end
end
