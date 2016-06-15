require 'bosh/template/property_helper'

module Bosh
  module Release
    class Compiler
      include Bosh::Template::PropertyHelper

      OPTIONS = {
        "blobstore_options" => { "blobstore_path" => "/var/vcap/micro_bosh/data/cache" },
        "blobstore_provider" => "local",
        "base_dir"  => "/var/vcap",
        "platform_name" => "ubuntu",
        "agent_uri" => "https://vcap:vcap@localhost:6969"
      }

      AGENT_START_RETRIES=16

      def initialize(options)
        @options = OPTIONS.merge(options)
        @logger = Logger.new(@options["logfile"] || STDOUT)

        FileUtils.mkdir_p(File.join(@options["base_dir"], "packages"))
        bsc_provider = @options["blobstore_provider"]
        bsc_options = @options["blobstore_options"]
        @logger.info("Creating Blobstore client with #{bsc_provider} provider and options #{bsc_options}")
        @blobstore_client = Bosh::Blobstore::Client.safe_create(bsc_provider, bsc_options)
      end

      def start
        # Start the "compile" or "apply"
        send(@options["command"].to_sym)
      end

      def apply_spec_json
        File.join(@options["base_dir"], "micro/apply_spec.json")
      end

      def apply_spec
        File.join(@options["base_dir"], "micro/apply_spec.yml")
      end

      def connect_to_agent
        num_tries = 0
        begin
          @agent = Bosh::Agent::Client.create(@options["agent_uri"], "user" => "vcap", "password" => "vcap")
          @agent.ping
        rescue => e
          num_tries += 1
          sleep 0.1
          # Dont retry forever
          retry if num_tries < AGENT_START_RETRIES
          @logger.warn("Error connecting to agent #{e.inspect}")
          raise
        end
      end

      def compile
        @logger.info("Compiling #{@options["manifest"]} with tarball #{@options["release"]}")
        connect_to_agent
        deployment_mf = Psych.load_file(File.expand_path(@options["manifest"]))
        @spec = prep_spec(deployment_mf)

        @packages = {}
        @spec["job"] = { "name" => @options[:job] }

        untar(@options["release"]) do |dir|
          release_mf = Psych.load_file("release.MF")
          jobs = []

          jobs_to_compile(@options[:job], deployment_mf).each do |spec_job|
            job = find_by_name(release_mf["jobs"], spec_job)
            job_path = File.expand_path("jobs/#{job["name"]}.tgz")
            jobs << apply_spec_job(job, job_path)

            if job["name"] == @options[:job]
              @spec["job"]["version"] = job["version"].to_s
              @spec["job"]["template"] = @options[:job]
              @spec["job"]["sha1"] = job["sha1"]
              @spec["job"]["blobstore_id"] = @blobstore_client.create(File.new(job_path))
            end

            untar(job_path) do
              job = Psych.load_file("job.MF")

              # add default job spec properties to apply spec
              add_default_properties(@spec["properties"], job["properties"])

              # Compile job packages
              compile_packages(dir, release_mf, job["packages"])
            end
          end

          @spec["job"]["templates"] = jobs
        end
        cleanup

        # save apply spec
        FileUtils.mkdir_p(File.dirname(apply_spec))
        if @options[:json]
          File.open(apply_spec_json, 'w') { |f| f.write(@spec.to_json) }
        else
          File.open(apply_spec, 'w') { |f| f.write(Psych.dump(@spec)) }
        end



        @spec["packages"]
      rescue => e
        @logger.error("Error #{e.message}, #{e.backtrace.join("\n")}")
      end

      def find_by_name(enum, name)
        result = enum.find { |j| j["name"] == name }
        if result
          result
        else
          raise "Could not find name #{name} in #{enum}"
        end
      end

      # Check manifest for job collocation
      def jobs_to_compile(name, manifest)
        compile_job = manifest["jobs"].find { |j| j["name"] == name } if manifest["jobs"]
        if compile_job
          compile_job["template"]
        else
          [name]
        end
      end

      def apply_spec_job(job, job_path)
        {
          "name" => job["name"],
          "version" => job["version"].to_s,
          "sha1" => job["sha1"],
          "blobstore_id" => @blobstore_client.create(File.new(job_path))
        }
      end

      def cleanup
        FileUtils.rm_rf("#{@options["base_dir"]}/data/compile")
        FileUtils.rm_rf("#{@options["base_dir"]}/data/packages")
        FileUtils.rm_rf("#{@options["base_dir"]}/data/tmp")
        FileUtils.rm_rf("#{@options["base_dir"]}/packages")
      end

      def prep_spec(deployment)
        spec = {}
        spec["deployment"] = "micro"
        spec["release"] = deployment["release"]
        spec["properties"] = deployment["properties"]
        spec["index"] = 0
        spec["packages"] = {}
        spec["configuration_hash"] = {}

        case @options[:cpi]
        when "vsphere", "vcloud"
          spec["networks"] = {"local" => {"ip" => "127.0.0.1"}}
        when "aws"
          spec["networks"] = {"type" => "dynamic"}
        when "google"
          spec["networks"] = {"type" => "dynamic"}
        when "openstack"
          spec["networks"] = {"type" => "dynamic"}
        when "azure"
          spec["networks"] = {"type" => "dynamic"}
        when "softlayer"
          spec["networks"] = {"type" => "dynamic"}
        else
          puts "WARNING: no CPI specified"
        end

        spec
      end

      def compile_packages(dir, manifest, packages)
        packages.each do |name|
          package = find_package(manifest, name)
          compile_packages(dir, manifest, package["dependencies"]) if package["dependencies"]

          @logger.debug "compiling package #{name}"
          compile_package(dir, package, name)
        end
      end

      def find_package(manifest, name)
        manifest["packages"].detect { |p| p["name"] == name }
      end

      def compile_package(dir, package, name)
        # return if package is already compiled
        return if @spec["packages"].has_key?(name)

        src = "#{dir}/packages/#{name}.tgz"
        version = package["version"]

        # push source package into blobstore
        file = File.new(src)
        id = @blobstore_client.create(file)

        sha1 = Digest::SHA1.file(src).hexdigest
        dependencies = {}
        package["dependencies"].each do |name|
          @logger.debug "dependency: #{name} = #{@spec["packages"][name]}"
          dependencies[name] = @spec["packages"][name]
        end

        result = @agent.run_task(:compile_package, id, sha1, name, "#{version}", dependencies)
        @logger.info("result is #{result}")

        # remove source package from blobstore
        @blobstore_client.delete(id)

        id = result["result"]["blobstore_id"]
        @logger.debug("stored package #{name} as #{id}")

        @spec["packages"][name] = {
          "name" => name,
          "version" => version.to_s,
          "sha1" => result["result"]["sha1"],
          "blobstore_id" => id
        }
      end

      def untar(file)
        prev_dir = Dir.getwd
        dir = Dir.mktmpdir
        Dir.chdir(dir)
        @logger.debug("untaring #{file} into #{dir}")
        out = `tar xzf #{file} 2>&1`
        raise RuntimeError, "untar of #{file} failed: #{out}" unless $? == 0
        yield dir
      ensure
        Dir.chdir(prev_dir)
        FileUtils.rm_rf dir
      end

      def apply
        connect_to_agent
        FileUtils.mkdir_p(File.join(@options["base_dir"], 'data/log'))
        # Stop services
        @logger.info("Stopping services")
        begin
          @agent.run_task(:stop)
        rescue => e
          @logger.warn("Ignoring error to stop services #{e.inspect}")
        end

        @spec = Psych.load_file(@options["apply_spec"])
        @logger.info("#{@spec.inspect}")
        update_bosh_spec
        @agent.run_task(:apply, @spec)

        @logger.info("Starting services")
        @agent.run_task(:start)
      end

      def update_bosh_spec
        uri = URI.parse(@options["agent_uri"])
        ip = uri.host
        properties = @spec["properties"]
        properties["blobstore"]["address"] = ip
        properties["postgres"]["address"] = ip
        properties["director"]["address"] = ip
        properties["nats"]["address"] = ip
        @spec["properties"] = properties
      end

      def add_default_properties(spec_properties, job_properties)
        return unless job_properties

        job_properties.each_pair do |name, definition|
          unless definition["default"].nil?
            copy_property(spec_properties, spec_properties, name, definition["default"])
          end
        end
      end

    end
  end
end

