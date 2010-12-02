require "json"
require "tmpdir"
require "digest/sha1"

module Bosh
  module Cli

    class Release

      POLL_TASK_INTERVAL = 1
      MAX_POLLS = 300

      class ValidationHalted < StandardError; end

      attr_reader :validation_log, :errors

      def initialize(tarball_path)
        @errors         = []
        @release_file   = File.expand_path(tarball_path, Dir.pwd)
        @validated      = false
      end

      def upload(api_client)
        return [ false, "Release is invalid, please fix and verify it before uploading" ] unless valid?

        status, body, headers = api_client.post("/releases", "application/x-compressed", File.read(@release_file))
        location = headers["Location"]

        scheduled = status == 302

        if scheduled
          if location !~ /^.+(\d+)\/?$/ # Doesn't look like we received URI
            return [ false, "Release uploaded but director doesn't support update progress tracking"]
          end

          poll_result = api_client.poll_job_status(location) do |polls, status|
            yield(polls, status) if block_given?
          end

          case poll_result
          when :done: [ true, "Release successfully uploaded and updated" ]
          when :timeout: [ false, "Uploaded but timed out while tracking update status" ]
          when :error: [ false, "Uploaded but received an error while tracking release update status" ]
          end
        else
          [ false, "Cannot upload release: #{status} #{body}" ]
        end
      end

      def valid?
        validate unless @validated
        errors.empty?        
      end

      def validate(&block)
        tmp_dir = Dir.mktmpdir("release")

        @step_callback = block if block_given?
        
        step("File exists and readable", "Cannot find release file #{@release_file}", :fatal) do
          File.exists?(@release_file) && File.readable?(@release_file)          
        end

        step("Extract tarball", "Cannot extract tarball #{@release_file}", :fatal) do
          `tar -C #{tmp_dir} -xzf #{@release_file} &> /dev/null`
          $?.exitstatus == 0
        end

        step("Manifest exists", "Cannot find release manifest", :fatal) do
          File.exists?(File.expand_path("release.MF", tmp_dir))
        end

        manifest = YAML.load_file(File.expand_path("release.MF", tmp_dir))

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
            `tar -C #{job_tmp_dir} -xzf #{job_file} &> /dev/null`
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
                job_manifest["configuration"].each do |config|
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

      rescue ValidationHalted
        # Basically just kind of 'goto'
      ensure
        @validated = true
      end

      private

      def step(name, error_message, kind = :non_fatal, &block)
        passed = yield
        if !passed
          @errors << error_message
          raise ValidationHalted if kind == :fatal
        end
      ensure
        @step_callback.call(name, passed) if @step_callback
      end
      
    end

  end
end
