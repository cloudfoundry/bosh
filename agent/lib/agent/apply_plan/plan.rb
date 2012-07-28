# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module ApplyPlan
    class Plan

      attr_reader :deployment
      attr_reader :job
      attr_reader :packages

      def initialize(spec)
        unless spec.is_a?(Hash)
          raise ArgumentError, "Invalid spec format, Hash expected, " +
                               "#{spec.class} given"
        end

        @spec = spec
        @deployment = spec["deployment"]
        @job = nil
        @packages = []
        @config_binding = Bosh::Agent::Util.config_binding(spec)

        job_spec = spec["job"]
        package_specs = spec["packages"]

        # By default stemcell VM has '' as job
        # in state.yml, handling this very special case
        if job_spec && job_spec != ""
          @job = Job.new(job_spec, @config_binding)
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
        !@job.nil?
      end

      def has_packages?
        !@packages.empty?
      end

      # TODO: figure out why it has to be an apply marker
      def configured?
        @spec.key?("configuration_hash")
      end

      def install_job
        @job.install if has_job?
      end

      def install_packages
        @packages.each do |package|
          package.install_for_job(@job)
        end
      end

      def configure_job
        @job.configure if has_job?
      end

    end
  end
end
