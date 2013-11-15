module Bosh::Agent
  module ApplyPlan
    class Plan

      attr_reader :deployment
      attr_reader :jobs
      attr_reader :packages

      def initialize(spec)
        unless spec.is_a?(Hash)
          raise ArgumentError, "Invalid spec format, Hash expected, " +
                               "#{spec.class} given"
        end

        @spec = spec
        @deployment = spec["deployment"]
        @jobs = []
        @packages = []
        @config_binding = Bosh::Agent::Util.config_binding(spec)

        job_spec = spec["job"]
        package_specs = spec["packages"]

        # By default stemcell VM has '' as job
        # in state.yml, handling this very special case
        if job_spec && job_spec != ""
          job_name = job_spec["name"]
          if is_legacy_spec?(job_spec)
            @jobs << Job.new(job_name, job_spec["template"], job_spec,
                @config_binding)
          else
            job_spec["templates"].each do |template_spec|
              @jobs << Job.new(job_name, template_spec["name"], template_spec,
                  @config_binding)
            end
          end
        end

        if package_specs
          unless package_specs.is_a?(Hash)
            raise ArgumentError, "Invalid package specs format " +
                                 "in apply spec, Hash expected " +
                                 "#{package_specs.class} given"
          end

          package_specs.each_pair do |package_name, package_spec|
            @packages << Package.new(package_spec)
          end
        end
      end

      def is_legacy_spec?(job_spec)
        return job_spec["template"] && !job_spec["templates"]
      end

      def has_jobs?
        !@jobs.empty?
      end

      def has_packages?
        !@packages.empty?
      end

      def configured?
        @spec.key?("configuration_hash")
      end

      def install_jobs
        @jobs.each do |job|
          job.install
        end
      end

      def install_packages
        @jobs.each do |job|
          @packages.each do |package|
            package.install_for_job(job)
          end
        end
      end

      # Configure the 1+ job templates (job colocation)
      # They are reversed for the purposes of ensuring monit
      # starts them in the order that they are specified
      # in the original deployment manifest
      def configure_jobs
        @jobs.reverse.each_with_index do |job, job_index|
          job.configure(job_index)
        end
      end
    end
  end
end
