module Bosh
  module PackageCompiler
    class Compiler

      APPLY_SPEC = '/var/vcap/micro/apply_spec.yml'
      OPTIONS = {
        "blobstore_options" => { "blobstore_path" => "/var/vcap/data/cache" },
        "blobstore_provider" => "local",
        "base_dir"  => "/var/vcap",
        "platform_name" => "ubuntu",
        "agent_uri" => "http://vcap:vcap@localhost:6969"
      }

      def connect_to_agent
        num_tries = 0
        begin
          @agent = Bosh::Agent::Client.create(@options["agent_uri"], "user" => "vcap" , "password" => "vcap")
          @agent.ping
        rescue => e
          num_tries += 1
          sleep 0.1
          retry if num_tries < 16
          @logger.warn("Error connecting to agent #{e.inspect}")
          raise
        end
      end

      def initialize
        @options = OPTIONS
        @args = ARGV.dup
        @logger = Logger.new(STDOUT)

        FileUtils.mkdir_p(File.join(@options["base_dir"], "packages"))

        bsc_provider = @options["blobstore_provider"]
        bsc_options = @options["blobstore_options"]
        @blobstore_client = Bosh::Blobstore::Client.create(bsc_provider, bsc_options)
      end

      def compile
        @manifest = @args[1]
        @tarball = @args[2]
        @logger.info("Compiling #{@manifest} with tarball #{@tarball}")
        connect_to_agent
        @spec = prep_spec(YAML.load_file(File.expand_path(@manifest)))
        @packages = {}
        untar(@tarball) do |dir|
          manifest = YAML.load_file("release.MF")
          micro_job = File.expand_path("jobs/micro.tgz")

          # add micro job to apply spec
          file = File.new(micro_job)
          id = @blobstore_client.create(file)
          @logger.debug "stored micro job as #{id}"
          job = manifest["jobs"].detect { |j| j["name"] == "micro" }
          # make sure version is a string or apply() will fail
          job["version"] = job["version"].to_s
          job["template"] = "micro"
          job["blobstore_id"] = id
          @spec["job"] = job

          # first do the micro package from the manifest
          micro = find_package(manifest, "micro")
          compile_packages(dir, manifest, micro["dependencies"])

          # then do the micro job
          untar(micro_job) do
            job = YAML.load_file("job.MF")
            compile_packages(dir, manifest, job["packages"])
          end
        end
        cleanup

        # save apply spec
        FileUtils.mkdir_p(File.dirname(APPLY_SPEC))
        File.open(APPLY_SPEC, 'w') { |f| f.write(YAML.dump(@spec)) }

        @spec["packages"]
      rescue => e
        @logger.error("Error #{e.message}, #{e.backtrace.join("\n")}")
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
        spec["networks"] = {"local" => {"ip" => "127.0.0.1"}}
        spec["packages"] = {}
        spec["configuration_hash"] = {}
        spec
      end

      def compile_packages(dir, manifest, packages)
        packages.each do |name|
          @logger.debug "compiling package #{name}"
          package = find_package(manifest, name)
          package["dependencies"].each do |dep|
            @logger.debug "compiling dependency #{dep}"
            pkg = find_package(manifest, dep)
            compile_package(dir, pkg, dep)
          end
          compile_package(dir, package, name)
        end
      end

      def find_package(manifest, name)
        manifest["packages"].detect { |p| p["name"] == name }
      end

      def compile_package(dir, package, name)
        return if @spec["packages"].has_key?(name)

        src = "#{dir}/packages/#{name}.tgz"
        version = package["version"]
        dependencies = package["dependencies"]

        # push source package into blobstore
        file = File.new(src)
        id = @blobstore_client.create(file)

        sha1 = "sha1"
        dependencies = {}
        package["dependencies"].each do |name|
          @logger.debug "dependency: #{name} = #{@spec["packages"][name]}"
          dependencies[name] = @spec["packages"][name]
        end

        result = @agent.run_task(:compile_package, id, sha1, name, version, dependencies)
        @logger.info("result is #{result}")

        # remove source package from blobstore
        cache = @options["blobstore_options"]["blobstore_path"]
        File.unlink("#{cache}/#{id}")

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
        @apply_spec = @args[1]
        @options = OPTIONS.merge("agent_uri" => @args[2])

        connect_to_agent
        FileUtils.mkdir_p('/var/vcap/data/log')
        # Stop services
        @logger.info("Stopping services")
        begin
          @agent.run_task(:stop)
        rescue
        end

        @spec = YAML.load_file(@apply_spec)
        @logger.info("#{@spec.inspect}")
        update_bosh_spec
        @agent.run_task(:apply, @spec)

        @logger.info("Starting services")
        @agent.run_task(:start)
      end

      def update_bosh_spec
        uri = URI.parse(@options["agent_uri"])
        ip = uri.host
        properties = @spec['properties']
        properties['blobstore']['address'] = ip
        properties['postgres']['address'] = ip
        properties['director']['address'] = ip
        properties['redis']['address'] = ip
        properties['nats']['address'] = ip
        @spec['properties'] = properties
      end

    end
  end
end

