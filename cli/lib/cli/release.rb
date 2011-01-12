require "tmpdir"
require "digest/sha1"

module Bosh
  module Cli

    class Release
      include Validation
      include DependencyHelper

      def initialize(tarball_path)
        @release_file = File.expand_path(tarball_path, Dir.pwd)
      end

      def perform_validation
        tmp_dir = Dir.mktmpdir

        step("File exists and readable", "Cannot find release file #{@release_file}", :fatal) do
          File.exists?(@release_file) && File.readable?(@release_file)          
        end

        step("Extract tarball", "Cannot extract tarball #{@release_file}", :fatal) do
          `tar -C #{tmp_dir} -xzf #{@release_file} 2>&1`
          $?.exitstatus == 0
        end

        manifest_file = File.expand_path("release.MF", tmp_dir)

        step("Manifest exists", "Cannot find release manifest", :fatal) do
          File.exists?(manifest_file)
        end

        manifest = YAML.load_file(manifest_file)

        step("Release name/version", "Manifest doesn't contain release name and/or version") do
          manifest.is_a?(Hash) && manifest.has_key?("name") && manifest.has_key?("version")
        end

        # Check packages
        total_packages = manifest["packages"].size
        available_packages = {}

        manifest["packages"].each_with_index do |package, i|
          name, version = package['name'], package['version']
          
          package_file   = File.expand_path(name + ".tgz", tmp_dir + "/packages")
          package_exists = File.exists?(package_file)

          step("Read package '%s' (%d of %d)" % [ name, i+1, total_packages ],
               "Missing package '#{name}'") do
            package_exists
          end

          if package_exists
            available_packages[name] = true
            step("Package '#{name}' checksum", "Incorrect checksum for package '#{name}'") do
              Digest::SHA1.hexdigest(File.read(package_file)) == package["sha1"]
            end
          end
        end

        # Check package dependencies
        if total_packages > 0
          step("Package dependencies", "Package dependencies couldn't be resolved") do
            begin
              tsort_packages(manifest["packages"].inject({}) { |h, p| h[p["name"]] = p["dependencies"] || []; h })
              true
            rescue Bosh::Cli::CircularDependency, Bosh::Cli::MissingDependency => e
              errors << e.message
              false
            end
          end
        end

        # Check jobs
        total_jobs = manifest["jobs"].size

        manifest["jobs"].each_with_index do |name, i|
          job_file   = File.expand_path(name + ".tgz", tmp_dir + "/jobs")
          job_exists = File.exists?(job_file)

          step("Read job '%s' (%d of %d)" % [ name, i+1, total_jobs ], "Job '#{name}' not found") do
            job_exists
          end

          if job_exists
            job_tmp_dir = "#{tmp_dir}/jobs/#{name}"
            FileUtils.mkdir_p(job_tmp_dir)
            `tar -C #{job_tmp_dir} -xzf #{job_file} 2>&1`
            job_extracted = $?.exitstatus == 0
            
            step("Extract job '#{name}", "Cannot extract job '#{name}'") do
              job_extracted
            end

            if job_extracted
              job_manifest_file   = File.expand_path("job.MF", job_tmp_dir)
              job_manifest        = YAML.load_file(job_manifest_file) if File.exists?(job_manifest_file)
              job_manifest_valid  = job_manifest.is_a?(Hash)
              
              step("Read job '#{name}' manifest", "Invalid job '#{name}' manifest") do
                job_manifest_valid
              end

              if job_manifest_valid && job_manifest["configuration"]
                job_manifest["configuration"].each_key do |config|
                  step("Check config '#{config}' for '#{name}'", "No config named '#{config}' for '#{name}'") do
                    File.exists?(File.expand_path(config, job_tmp_dir + "/config"))
                  end
                end
              end

              if job_manifest_valid && job_manifest["packages"]
                job_manifest["packages"].each do |package_name|
                  step("Job '#{name}' needs '#{package_name}' package", "'Job '#{name}' references missing package '#{package_name}'") do
                    available_packages[package_name]
                  end
                end
              end

              step("Monit file for '#{name}'", "Monit script missing for job '#{name}'") do
                File.exists?(File.expand_path("monit", job_tmp_dir))
              end
            end
          end
        end

        print_info(manifest)
      ensure
        FileUtils.rm_rf(tmp_dir)
      end

      def print_info(manifest)
        say("\nRelease info")
        say("------------")

        say "Name:    %s" % [ manifest["name"] ]
        say "Version: %s" % [ manifest["version"] ]

        say "\n"
        say "Packages"

        if manifest["packages"].size == 0
          say "  - none"
        end
        
        for package in manifest["packages"]
          say "  - %s (%s)" % [ package["name"], package["version"] ]
        end

        say "\n"
        say "Jobs"

        if manifest["jobs"].size == 0
          say "  - none"
        end        

        for job in manifest["jobs"]
          say "  - %s" % [ job ]
        end
      end
      
    end

  end
end
