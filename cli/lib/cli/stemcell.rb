# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli

    class Stemcell
      include Validation

      attr_reader :stemcell_file, :manifest

      def initialize(tarball_path, cache)
        @stemcell_file = File.expand_path(tarball_path, Dir.pwd)
        @cache = cache
      end

      def perform_validation(options = {})
        tmp_dir = Dir.mktmpdir

        step("File exists and readable", "Cannot find stemcell file #{@stemcell_file}", :fatal) do
          File.exists?(@stemcell_file) && File.readable?(@stemcell_file)
        end

        cache_key = "%s_%s" % [ @stemcell_file, File.mtime(@stemcell_file) ]

        manifest_yaml = @cache.read(cache_key)

        if manifest_yaml
          say("Using cached manifest...")
        else
          say("Manifest not found in cache, verifying tarball...")

          step("Extract tarball", "Cannot extract tarball #{@stemcell_file}", :fatal) do
            `tar -C #{tmp_dir} -xzf #{@stemcell_file} 2>&1`
            $?.exitstatus == 0
          end

          manifest_file = File.expand_path("stemcell.MF", tmp_dir)

          step("Manifest exists", "Cannot find stemcell manifest", :fatal) do
            File.exists?(manifest_file)
          end

          step("Stemcell image file", "Stemcell image file is missing", :fatal) do
            File.exists?(File.expand_path("image", tmp_dir))
          end

          say("Writing manifest to cache...")
          manifest_yaml = File.read(manifest_file)
          @cache.write(cache_key, manifest_yaml)
        end

        manifest = YAML.load(manifest_yaml)

        step("Stemcell properties", "Manifest should contain valid name, version and cloud properties") do
          manifest.is_a?(Hash) && manifest.has_key?("name") && manifest.has_key?("version") &&
            manifest.has_key?("cloud_properties") &&
            manifest["name"].is_a?(String) &&
            (manifest["version"].is_a?(String) || manifest["version"].kind_of?(Numeric)) &&
            (manifest["cloud_properties"].nil? || manifest["cloud_properties"].is_a?(Hash))
        end

        print_info(manifest)
        @manifest = manifest
      ensure
        FileUtils.rm_rf(tmp_dir)
      end

      def print_info(manifest)
        say("\nStemcell info")
        say("-------------")

        say "Name:    %s" % [ manifest["name"] || "missing".red ]
        say "Version: %s" % [ manifest["version"] || "missing".red ]
      end

    end

  end
end
