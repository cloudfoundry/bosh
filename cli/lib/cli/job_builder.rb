module Bosh::Cli
  class JobBuilder

    attr_reader :name, :packages, :configs, :release_dir, :job_dir, :built_packages

    def initialize(spec, release_dir, built_packages = [])
      spec = YAML.load_file(spec) if spec.is_a?(String) && File.file?(spec)
      
      @name      = spec["name"]
      @packages  = spec["packages"]

      @configs   = \
      case spec["configuration"]
      when Hash
        spec["configuration"].keys
      else
        spec["configuration"]
      end

      if @name.blank?
        raise InvalidJob, "Job name is missing"
      end

      unless @name.bosh_valid_id?
        raise InvalidJob, "Job name should be a valid Bosh identifier"
      end

      @built_packages = built_packages
      @release_dir    = release_dir
      @job_dir        = File.join(release_dir, "jobs", @name)
      @configs_dir    = File.join(job_dir, "config")
      @tarballs_dir   = @job_dir
    end

    def build

      unless File.exists?(File.join(job_dir, "spec"))
        raise InvalidJob, "Cannot find spec file for '#{name}'"
      end
      
      if missing_packages.size > 0
        raise InvalidJob, "Some packages required by '#{name}' job are missing: %s" % [ missing_packages.join(", ") ]
      end

      if missing_configs.size > 0
        raise InvalidJob, "Some config files required by '#{name}' job are missing: %s" % [ missing_configs.join(", ")]
      end

      unless File.exists?(File.join(job_dir, "monit"))
        raise InvalidJob, "Cannot find monit file for '#{name}'"
      end

      copy_files
      copy_manifest
      generate_tarball

      @job_built = true
    ensure
      FileUtils.rm_rf(build_dir)
      rollback unless @job_built
    end

    def rollback
      # TBD
    end

    def copy_files
      FileUtils.mkdir_p(File.join(build_dir, "config"))

       configs.each do |config|
        FileUtils.cp(File.join(@configs_dir, config), File.join(build_dir, "config"))
      end

      FileUtils.cp(File.join(job_dir, "monit"), build_dir)

      @files_copied = true
    end

    def copy_manifest
      FileUtils.cp(File.join(job_dir, "spec"), File.join(build_dir, "job.MF"))
      @manifest_copied = true
    end

    def generate_tarball
      copy_files unless @files_copied
      copy_manifest unless @manifest_copied

      in_build_dir do
        `tar -czf #{tarball_path} .`
        raise InvalidJob, "Cannot create job tarball" unless $?.exitstatus == 0
      end

      @tarball_generated = true
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def tarball_path
      File.join(@tarballs_dir, "#{name}.tgz")
    end    

    private

    def missing_packages
      @missing_packages ||= packages - built_packages
    end

    def missing_configs
      configs.select do |config|
        !File.exists?(File.join(@configs_dir, config))
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end
    
  end
end
