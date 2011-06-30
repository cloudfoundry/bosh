require 'tmpdir'
require 'agent'
require 'agent/util'

module VCAP
  module Micro

    class BindingHelper
      attr_reader :spec
      def initialize(spec)
        @spec = spec
      end
      def to_binding
        binding
      end
    end

    class Compiler
      OPTIONS = {
        "configure" => false,
        "logging"   => { "level" => "DEBUG" },
        "mbus"      => "nats://localhost:4222",
        "agent_id"  => "micro",
        "blobstore_options" => { "blobstore_path" => "/var/vcap/data/cache" },
        "blobstore_provider" => "local",
        "base_dir"  => "/var/vcap",
        "platform_name" => "ubuntu"
      }

      def initialize(deployment, tarball, options={})
        Bosh::Agent::Config.setup(OPTIONS.merge(options))
        @deployment = YAML.load_file(File.expand_path(deployment))
        @spec = prep_spec(@deployment)
        @binding = BindingHelper.new(@spec).to_binding
        @tarball = File.expand_path(tarball)
        @jobs = {}
        @packages = {}
        @logger = Bosh::Agent::Config.logger
        @cache = Bosh::Agent::Config.blobstore_options["blobstore_path"]
        mkdir(@cache)
        @base_dir = Bosh::Agent::Config.base_dir
        %w{data/jobs data/packages packages jobs}.each do |dir|
          mkdir("#{@base_dir}/#{dir}")
        end
      end

      def prep_spec(deployment)
        spec = {}
        spec["deployment"] = "micro"
        spec["release"] = deployment["release"]
        spec["properties"] = deployment["properties"]
        spec["index"] = 0
        spec["networks"] = {"local" => {"ip" => "127.0.0.1"}}
        spec["packages"] = {}
        spec
      end

      def run
        untar(@tarball) do |dir|
          manifest = YAML.load_file("release.MF")
          job = manifest["jobs"].detect { |j| j["name"] == "micro" }
          raise ArgumentError, "could not find 'micro' job" unless job
          prepare_job(dir, manifest, job)
          File.open('/var/vcap/micro/apply_spec.yml', 'w') { |f| f.write(YAML.dump(@spec)) }
        end
      end

      def prepare_job(source, manifest, job)
        name = job["name"]
        version = job["version"]
        @logger.info("preparing job #{name} version #{version}")

        # add job dependencies
        package_dependencies(manifest, job["name"]).each do |dependency|
          @logger.info "installing package dependency: #{dependency}"
          install_package(source, manifest, find_package(manifest, dependency))
        end

        job_file = "#{source}/jobs/#{name}.tgz"
        job_dir = "#{@base_dir}/data/jobs/#{name}/#{version}"
        untar(job_file) do |dir|
          job_manifest = YAML.load_file("job.MF")
          prepare_templates(job_dir, job_manifest["templates"])
          prepare_monit(job_dir)
          manifest["packages"].each do |package|
            @logger.info("installing package #{package["name"]}")
            install_package(source, manifest, package)
          end
        end

        job["template"] = name
        job["blobstore_id"] = "#{name}.tgz"
        @spec["job"] = job
        FileUtils.ln_sf(job_dir, "#{@base_dir}/jobs/#{name}")
        FileUtils.cp(job_file, "#{@cache}/#{name}.tgz")
      end

      def prepare_monit(dst)
        mkdir(dst)
        # monit -> /var/vcap/data/jobs/micro/v/micro.monitrc
        FileUtils.cp("monit", "#{dst}/micro.monitrc")
        # micro.monitrc -> /var/vcap/monit/micro.monitrc
        FileUtils.ln_sf("#{dst}/micro.monitrc", "/var/vcap/monit")
      end

      def prepare_templates(job_dir, templates)
        mkdir(job_dir)
        name = "micro"
        index = @spec['index']
        properties = @spec['properties'].to_openstruct
        spec = @spec.to_openstruct
        binding = Bosh::Agent::Util::BindingHelper.new(name, index, properties, spec).get_binding

        templates.each do |src, dst|
          puts "#{src} -> #{dst}"
          erb = ERB.new(File.read(File.join("templates", src)))

          out_file = File.join(job_dir, dst)
          FileUtils.mkdir_p(File.dirname(out_file))

          File.open(out_file, 'w') do |f|
            f.write(erb.result(binding))
          end

          if File.dirname(out_file) =~ /bin/
            puts "chmoding #{out_file}"
            FileUtils.chmod(0755, out_file)
          end
        end
      end

      def install_package(source, manifest, package)
        name = package["name"]
        version = package["version"]

        if @packages.include?(name)
          @logger.debug "package #{name} already installed"
          return
        end

        package["dependencies"].each do |dependency|
          @logger.info "installing package dependency: #{dependency}"
          install_package(source, manifest, find_package(manifest, dependency))
        end

        dst = "#{@base_dir}/data/packages/#{name}/#{version}"
        lnk = "#{@base_dir}/packages/#{name}"
        untar("#{source}/packages/#{name}.tgz") do |dir|
          puts "compiling #{name}"
          compile(dir, dst, name, version)
          sha1 = pack(dst, name)
          @spec["packages"][name] = {
            "name" => name,
            "version" => version,
            "sha1" => sha1,
            "blobstore_id" => "#{name}.tgz"
          }
          @packages[name] = true
        end
        FileUtils.ln_sf(dst, lnk)
      end

      # code copied from agent/message/compile_package.rb
      def compile(compile, install, name, version)
        FileUtils.rm_rf install if File.directory?(install)
        FileUtils.mkdir_p install

        # Prevent these from getting inhereted from the agent
        %w{GEM_HOME BUNDLE_GEMFILE RUBYOPT}.each { |key| ENV.delete(key) }

        # TODO: error handling
        ENV['BOSH_COMPILE_TARGET'] = compile
        ENV['BOSH_INSTALL_TARGET'] = install
        if File.exist?('packaging')
          @logger.info("Compiling #{name} #{version}")
          output = `bash -x packaging 2>&1`
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError,
              "Compile Package Failure (exit code: #{$?.exitstatus}): #{output}"
          end
          @logger.debug(output)
        end
      end

      def package_dependencies(manifest, package_name)
        p = manifest["packages"].detect { |p| p["name"] == package_name }
        p.nil? ? [] : p["dependencies"]
      end

      def untar(file)
        Dir.mktmpdir do |dir|
          Dir.chdir(dir)
          @logger.debug("untaring #{file} into #{dir}")
          `tar xzf #{file}`
          yield dir
        end
      end

      def find_package(manifest, name)
        manifest["packages"].detect { |p| p["name"] == name }
      end

      def pack(dir, name)
        Dir.chdir(dir)
        dest = "#{@cache}/#{name}.tgz"
        `tar czf #{dest} .`
        sha = Digest::SHA1.hexdigest(File.read(dest))
      end

      def mkdir(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

    end
  end
end