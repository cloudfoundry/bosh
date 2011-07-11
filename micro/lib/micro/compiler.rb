module Bosh; end

require 'logger'
require 'openssl'
require 'tmpdir'
require 'tempfile'
require 'yajl'
require 'yaml'

require 'agent'

module VCAP
  module Micro

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

      def initialize(options={})
        Bosh::Agent::Config.setup(OPTIONS.merge(options))
        @logger = Bosh::Agent::Config.logger

        bsc_provider = Bosh::Agent::Config.blobstore_provider
        bsc_options = Bosh::Agent::Config.blobstore_options
        @blobstore_client = Bosh::Blobstore::Client.create(bsc_provider, bsc_options)

        FileUtils.mkdir_p(bsc_options["blobstore_path"])
        FileUtils.mkdir_p(File.join(options["base_dir"], "packages"))
      end

      def compile(deployment, tarball)
        @spec = prep_spec(YAML.load_file(File.expand_path(deployment)))
        @packages = {}
        untar(tarball) do |dir|
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
        apply_spec = File.join(Bosh::Agent::Config.base_dir, 'micro/apply_spec.yml')
        FileUtils.mkdir_p(File.dirname(apply_spec))
        File.open(apply_spec, 'w') { |f| f.write(YAML.dump(@spec)) }

        @spec["packages"]
      end

      # remove files & directories generated by the compilation
      def cleanup
        base_dir = Bosh::Agent::Config.base_dir
        FileUtils.rm_rf("#{base_dir}/data/compile")
        FileUtils.rm_rf("#{base_dir}/data/packages")
        FileUtils.rm_rf("#{base_dir}/data/tmp")
        FileUtils.rm_rf("#{base_dir}/packages")
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
        args = [id, sha1, name, version, dependencies]
        result = Bosh::Agent::Message::CompilePackage.process(args)

        # remove source package from blobstore
        cache = Bosh::Agent::Config.blobstore_options["blobstore_path"]
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
        # can't use mktmpdir with a block as it masks the file location
        # in rspec and you won't get a useful stacktrace
        dir = Dir.mktmpdir
        Dir.chdir(dir)
        @logger.debug("untaring #{file} into #{dir}")
        `tar xzf #{file}`
        raise RuntimeError, "untar of #{file} failed" unless $? == 0
        yield dir
        FileUtils.rm_rf dir
      end

    end
  end
end
