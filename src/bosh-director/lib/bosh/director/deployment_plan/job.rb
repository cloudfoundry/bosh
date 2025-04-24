require 'bosh/common/template/property_helper'

module Bosh::Director
  module DeploymentPlan
    class Job
      include Bosh::Common::Template::PropertyHelper
      include ValidationHelper

      attr_reader :name
      attr_reader :release

      attr_reader :model
      attr_reader :package_models

      attr_reader :link_infos
      attr_reader :properties

      # @param [DeploymentPlan::ReleaseVersion] release Release version
      # @param [String] name Template name
      def initialize(release, name)
        @release = release
        @name = name
        @model = nil
        @package_models = []
        @logger = Config.logger
        @link_infos = {}

        # This hash will contain the properties specific to this job,
        # it will be a hash where the keys are the deployment instance groups name, and
        # the value of each key will be the properties defined in job
        # section of the deployment manifest. This way if a job is used
        # in multiple instance groups, the properties will not be shared across
        # instance groups
        @properties = {}
      end

      # Looks up job model and its package models in DB.
      #
      # Here “template” is the old Bosh v1 name for “job”.
      #
      # @return [void]
      def bind_models
        @model = @release.get_template_model_by_name(@name)

        if @model.nil?
          raise DeploymentUnknownTemplate, "Can't find job '#{@name}'"
        end

        @package_models = @model.package_names.map do |name|
          @release.get_package_model_by_name(name)
        end
      end

      def bind_existing_model(model)
        @model = model
      end

      # Downloads job blob to a given path
      #
      # @return [String] Path to downloaded blob
      def download_blob
        uuid = SecureRandom.uuid
        path = File.join(Dir.tmpdir, "job-#{uuid}")

        @logger.debug("Downloading job '#{@name}' (#{blobstore_id})...")
        t1 = Time.now

        File.open(path, "w") do |f|
          App.instance.blobstores.blobstore.get(blobstore_id, f, sha1: present_model.sha1)
        end

        @logger.debug("Job '#{@name}' downloaded to #{path} " +
                      "(took #{Time.now - t1}s)")

        path
      end

      # @return [String]
      def version
        present_model.version
      end

      # @return [String]
      def sha1
        present_model.sha1
      end

      # @return [String]
      def blobstore_id
        present_model.blobstore_id
      end

      # @return [Array]
      def logs
        present_model.logs
      end

      def runs_as_errand?
        @release.bind_model
        @release.bind_jobs
        !@model.nil? && @model.runs_as_errand?
      end

      def add_properties(properties, instance_group_name)
        @properties[instance_group_name] = properties
      end

      def bind_properties(instance_group_name)
        bound_properties = {}
        @properties[instance_group_name] ||= {}

        release_job_spec_properties.each_pair do |name, definition|
          validate_properties_format(@properties[instance_group_name], name)

          provided_property_value = lookup_property(@properties[instance_group_name], name)
          property_value_to_use = provided_property_value.nil? ? definition['default'] : provided_property_value
          sorted_property = sort_property(property_value_to_use)
          set_property(bound_properties, name, sorted_property)
        end
        @properties[instance_group_name] = bound_properties
      end

      private

      # Returns model only if it's present, fails otherwise
      # @return [Models::Template]
      def present_model
        if @model.nil?
          raise DirectorError, "Job '#{@name}' model is unbound"
        end
        @model
      end

      # @return [Hash]
      def release_job_spec_properties
        present_model.properties
      end

      def links_of_kind_for_instance_group_name(instance_group_name, kind)
        if link_infos.has_key?(instance_group_name) && link_infos[instance_group_name].has_key?(kind)
          return link_infos[instance_group_name][kind]
        end

        []
      end
    end
  end
end
