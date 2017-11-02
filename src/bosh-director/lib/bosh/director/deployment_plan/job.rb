require 'bosh/template/property_helper'

module Bosh::Director
  module DeploymentPlan
    class Job
      include Bosh::Template::PropertyHelper
      include ValidationHelper

      attr_reader :name
      attr_reader :release

      attr_reader :model
      attr_reader :package_models

      attr_reader :link_infos
      attr_reader :properties

      # @param [DeploymentPlan::ReleaseVersion] release Release version
      # @param [String] name Template name
      # @param [String] deployment_name The name of the deployment
      def initialize(release, name, deployment_name)
        @release = release
        @name = name
        @model = nil
        @package_models = []
        @logger = Config.logger
        @link_infos = {}
        @config_server_client = Bosh::Director::ConfigServer::ClientFactory.create(@logger).create_client

        # This hash will contain the properties specific to this job,
        # it will be a hash where the keys are the deployment instance groups name, and
        # the value of each key will be the properties defined in job
        # section of the deployment manifest. This way if a job is used
        # in multiple instance groups, the properties will not be shared across
        # instance groups
        @properties = {}
      end

      # Looks up template model and its package models in DB
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

      # Downloads template blob to a given path
      # @return [String] Path to downloaded blob
      def download_blob
        uuid = SecureRandom.uuid
        path = File.join(Dir.tmpdir, "template-#{uuid}")

        @logger.debug("Downloading job '#{@name}' (#{blobstore_id})...")
        t1 = Time.now

        File.open(path, "w") do |f|
          App.instance.blobstores.blobstore.get(blobstore_id, f)
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

      # return [Array]
      def model_consumed_links
        present_model.consumes.to_a.map { |l| TemplateLink.parse('consumes', l) }
      end

      # return [Array]
      def model_provided_links
        present_model.provides.to_a.map { |l| TemplateLink.parse('provides', l) }
      end

      # return [Array]
      def consumed_links(instance_group_name)
        consumes_links_for_instance_group_name(instance_group_name).map do |_, link_info|
          TemplateLink.parse('consumes', link_info)
        end
      end

      # return [Array]
      def provided_links(instance_group_name)
        provides_links_for_instance_group_name(instance_group_name).map do |_, link_info|
          TemplateLink.parse('provides', link_info)
        end
      end

      def runs_as_errand?
        @release.bind_model
        @release.bind_templates
        !@model.nil? && @model.runs_as_errand?
      end

      def consumes_links_for_instance_group_name(instance_group_name)
        links_of_kind_for_instance_group_name(instance_group_name, 'consumes')
      end

      def provides_links_for_instance_group_name(instance_group_name)
        links_of_kind_for_instance_group_name(instance_group_name, 'provides')
      end

      def add_link_from_release(instance_group_name, kind, link_name, source)
      #TODO populate new provider object
        @link_infos[instance_group_name] ||= {}
        @link_infos[instance_group_name][kind] ||= {}
        @link_infos[instance_group_name][kind][link_name] ||= {}

        if source.eql? 'nil'
          # This is the case where the user set link source to nil explicitly in the deployment manifest
          # We should skip the binding of this link, even if it exist. This is used only when the link
          # is optional
          @link_infos[instance_group_name][kind][link_name]['skip_link'] = true
        else
          source.to_a.each do |key, value|
            if key == "properties"
              key = "link_properties_exported"
            end
            @link_infos[instance_group_name][kind][link_name][key] = value
          end
        end
      end

      def add_link_from_manifest(instance_group_name, kind, link_name, source)
        #TODO populate new provider object
        @link_infos[instance_group_name] ||= {}
        @link_infos[instance_group_name][kind] ||= {}
        @link_infos[instance_group_name][kind][link_name] ||= {}

        if source.eql? 'nil'
          # This is the case where the user set link source to nil explicitly in the deployment manifest
          # We should skip the binding of this link, even if it exist. This is used only when the link
          # is optional
          @link_infos[instance_group_name][kind][link_name]['skip_link'] = true
        else
          errors = []
          if kind == "consumes"
            errors = validate_consume_link(source, link_name, instance_group_name)
          elsif kind == "provides"
            errors.concat(validate_provide_link(link_name, instance_group_name))
          end
          errors.concat(validate_link_def(source, link_name, instance_group_name))

          if errors.size > 0
            raise errors.join("\n")
          end

          source_hash = source.to_a
          source_hash.each do |key, value|
            @link_infos[instance_group_name][kind][link_name][key] = value
          end
        end
      end

      def consumes_link_info(instance_group_name, link_name)
        @link_infos.fetch(instance_group_name, {}).fetch('consumes', {}).fetch(link_name, {})
      end

      def provides_link_info(instance_group_name, link_name)
        @link_infos.fetch(instance_group_name, {}).fetch('provides', {}).each do |index, link|
          if link['as'] == link_name
            return link
          end
        end
        return @link_infos.fetch(instance_group_name, {}).fetch('provides', {}).fetch(link_name, {})
      end

      def add_properties(properties, instance_group_name)
        @properties[instance_group_name] = properties
      end

      def bind_properties(instance_group_name, deployment_name, options = {})
        bound_properties = {}
        @properties[instance_group_name] ||= {}

        release_job_spec_properties.each_pair do |name, definition|
          validate_properties_format(@properties[instance_group_name], name)

          provided_property_value = lookup_property(@properties[instance_group_name], name)
          property_value_to_use = @config_server_client.prepare_and_get_property(
            provided_property_value,
            definition['default'],
            definition['type'],
            deployment_name,
            options
          )
          sorted_property = sort_property(property_value_to_use)
          set_property(bound_properties, name, sorted_property)
        end
        @properties[instance_group_name] = bound_properties
      end

      private

      def validate_consume_link(source, link_name, instance_group_name)
        blacklist = [ ['instances', 'from'], ['properties', 'from'] ]
        errors = []
        if source == nil
          return errors
        end

        blacklist.each do |invalid_props|
          if invalid_props.all? { |prop| source.has_key?(prop) }
            errors.push("Cannot specify both '#{invalid_props[0]}' and '#{invalid_props[1]}' keys for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'.")
          end
        end

        if source.has_key?('properties') && !source.has_key?('instances')
          errors.push("Cannot specify 'properties' without 'instances' for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'.")
        end

        if source.has_key?('ip_addresses')
          unless !!source['ip_addresses'] == source['ip_addresses']
            errors.push("Cannot specify non boolean values for 'ip_addresses' field for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'.")
          end
        end

        errors
      end

      def validate_provide_link(link_name, instance_group_name)
        # Assumption: release spec has been parsed prior to the manifest being
        # parsed. This way, we can check to see if there are any provides link being provided.
        errors = []
        if @link_infos[instance_group_name]["provides"][link_name].empty?
          errors.push("Job '#{instance_group_name}' does not provide link '#{link_name}' in the release spec")
        end

        return errors
      end

      def validate_link_def(source, link_name, instance_group_name)
        errors = []
        if !source.nil? && (source.has_key?('name') || source.has_key?('type'))
          errors.push("Cannot specify 'name' or 'type' properties in the manifest for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'. Please provide these keys in the release only.")
        end
        errors
      end

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
        return []
      end
    end
  end
end
