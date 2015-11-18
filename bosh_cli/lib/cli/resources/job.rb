module Bosh::Cli::Resources
  class Job
    BUILD_HOOK_FILES = ['prepare']

    # @param [String] directory base Release directory
    def self.discover(release_base, packages)
      jobs_folder_contents = Dir[File.join(release_base, 'jobs', '*')]
      job_folders = jobs_folder_contents.select { |f| File.directory?(f) }
      job_folders.map { |job_base| new(job_base, release_base, packages) }
    end

    attr_reader :job_base, :release_base, :package_dependencies

    def initialize(job_base, release_base, packages)
      @release_base = Pathname.new(release_base)
      @job_base = Pathname.new(job_base)
      @package_dependencies = packages
    end

    def spec
      @spec ||= load_yaml_file(job_base.join('spec'))
    rescue Exception => e
      raise Bosh::Cli::InvalidJob, "Job spec is missing or invalid: #{e.message}"
    end

    def name
      spec['name']
    end

    def additional_fingerprints
      []
    end

    def dependencies
      package_dependencies #TODO: should this be packages or package_dependencies?
    end

    def singular_type
      'job'
    end

    def plural_type
      'jobs'
    end

    def files
      files = (templates_files + monit_files).map { |absolute_path| [absolute_path, relative_path(absolute_path)] }
      files << [File.join(job_base, 'spec'), 'job.MF']
      files
    end

    # TODO: check dependency packages
    def validate!
      if name.blank?
        raise Bosh::Cli::InvalidJob, 'Job name is missing'
      end

      unless name.bosh_valid_id?
        raise Bosh::Cli::InvalidJob, "'#{name}' is not a valid BOSH identifier"
      end

      unless spec['templates'].is_a?(Hash)
        raise Bosh::Cli::InvalidJob, "Incorrect templates section in '#{name}' job spec (Hash expected, #{spec['templates'].class} given)"
      end

      if extra_templates.size > 0
        raise Bosh::Cli::InvalidJob, "There are unused template files for job '#{name}': #{extra_templates.join(", ")}"
      end

      if missing_templates.size > 0
        raise Bosh::Cli::InvalidJob, "Some template files required by '#{name}' job are missing: #{missing_templates.join(", ")}"
      end

      if missing_packages.size > 0
        raise Bosh::Cli::InvalidJob, "Some packages required by '#{name}' job are missing: #{missing_packages.join(", ")}"
      end

      if spec.has_key?('properties')
        unless spec['properties'].is_a?(Hash)
          raise Bosh::Cli::InvalidJob, "Incorrect properties section in '#{name}' job spec (Hash expected, #{spec['properties'].class} given)"
        end
      end

      unless monit_files.size > 0
        raise Bosh::Cli::InvalidJob, "Cannot find monit file for '#{name}'"
      end
    end

    def format_fingerprint(digest, filename, name, file_mode)
      "%s%s%s" % [File.basename(filename), digest, file_mode]
    end

    def run_script(script_name, *args)
      if BUILD_HOOK_FILES.include?(script_name.to_s)
        send(:"run_script_#{script_name}", *args)
      end
    end

    def properties
      spec['properties'] || {}
    end

    private

    def extra_templates
      return [] if !File.directory?(templates_dir)

      Dir.chdir(templates_dir) do
        Dir["**/*"].reject do |file|
          File.directory?(file) || templates.include?(file)
        end
      end
    end

    def missing_packages
      @missing_packages ||= (packages - package_dependencies)
    end

    def missing_templates
      templates.select do |template|
        !File.exists?(File.join(templates_dir, template))
      end
    end

    def monit_files
      monit = File.join(job_base, 'monit')
      files = Dir.glob(File.join(job_base, '*.monit'))
      files << monit if File.exist?(monit)
      files
    end

    def packages
      spec['packages'] || []
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(job_base).to_s
    end

    def templates
      spec['templates'].keys
    end

    def templates_dir
      @templates_dir ||= job_base.join('templates')
    end

    def templates_files
      templates.map { |file| File.join(templates_dir, file) }
    end

    def run_script_prepare
      script_path = File.join(job_base, 'prepare')

      return nil unless File.exists?(script_path)

      unless File.executable?(script_path)
        raise Bosh::Cli::InvalidJob, "Prepare script at '#{script_path}' is not executable"
      end

      old_env = ENV
      script_dir = File.dirname(script_path)
      script_name = File.basename(script_path)

      begin
        # We need to temporarily delete some rubygems related artefacts
        # because preparation scripts shouldn't share any assumptions
        # with CLI itself
        %w{ BUNDLE_GEMFILE RUBYOPT }.each { |key| ENV.delete(key) }

        output = nil
        Dir.chdir(script_dir) do
          cmd = "./#{script_name} 2>&1"
          output = `#{cmd}`
        end

        unless $?.exitstatus == 0
          raise Bosh::Cli::InvalidJob, "'#{script_path}' script failed: #{output}"
        end

        output
      ensure
        ENV.each_pair { |k, v| ENV[k] = old_env[k] }
      end
    end
  end
end
