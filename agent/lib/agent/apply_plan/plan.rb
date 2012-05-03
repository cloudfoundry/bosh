# Copyright (c) 2009-2012 VMware, Inc.

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
          job_spec["templates"].each do |template_spec|
            @jobs.push(Job.new(job_name, template_spec, @config_binding))
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

      def has_job?
        !@jobs.empty?
      end

      def has_packages?
        !@packages.empty?
      end

      # TODO: figure out why it has to be an apply marker
      def configured?
        @spec.key?("configuration_hash")
      end

      def install_jobs
        if has_job?
          @jobs.each do |job|
            job.install
          end
        end
      end

      def install_packages
        @jobs.each do |job|
          @packages.each do |package|
            package.install_for_job(job)
          end
        end
      end

      def configure_job
        @jobs.each do |job|
          job.configure if has_job?
        end
      end

    end
  end
end
