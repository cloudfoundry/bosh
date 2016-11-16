require 'bosh/director/config_server/config_server_helper'

module Bosh::Director::ConfigServer
  class EnabledClient
    include ConfigServerHelper

    def initialize(http_client, director_name, logger)
      @config_server_http_client = http_client
      @director_name = director_name
      @deep_hash_replacer = DeepHashReplacement.new
      @logger = logger
    end

    # @param [Hash] src Hash to be interpolated
    # @param [String] deployment_name The deployment context in-which the interpolation
    # will occur (used mostly for links properties interpolation since they will be interpolated in
    # the context of the deployment providing these links)
    # @param [Hash] options Additional options
    #   Options include:
    #   - 'subtrees_to_ignore': [Array] Array of paths that should not be interpolated in src
    #   - 'must_be_absolute_name': [Boolean] Flag to check if all the placeholders start with '/'
    # @return [Hash] A Deep copy of the interpolated src Hash
    def interpolate(src, deployment_name, options = {})
      subtrees_to_ignore = options.fetch(:subtrees_to_ignore, [])
      must_be_absolute_name = options.fetch(:must_be_absolute_name, false)

      placeholders_paths = @deep_hash_replacer.placeholders_paths(src, subtrees_to_ignore)
      placeholders_list = placeholders_paths.map { |c| c['placeholder'] }.uniq

      retrieved_config_server_values, missing_names = fetch_names_values(placeholders_list, deployment_name, must_be_absolute_name)
      if missing_names.length > 0
        raise Bosh::Director::ConfigServerMissingNames, "Failed to load placeholder names from the config server: #{missing_names.join(', ')}"
      end

      @deep_hash_replacer.replace_placeholders(src, placeholders_paths, retrieved_config_server_values)
    end

    # @param [Hash] deployment_manifest Deployment Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_deployment_manifest(deployment_manifest)
      ignored_subtrees = [
        ['properties'],
        ['instance_groups', Integer, 'properties'],
        ['instance_groups', Integer, 'jobs', Integer, 'properties'],
        ['instance_groups', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
        ['jobs', Integer, 'properties'],
        ['jobs', Integer, 'templates', Integer, 'properties'],
        ['jobs', Integer, 'templates', Integer, 'consumes', String, 'properties'],
        ['instance_groups', Integer, 'env'],
        ['jobs', Integer, 'env'],
        ['resource_pools', Integer, 'env'],
      ]

      interpolate(
        deployment_manifest,
        deployment_manifest['name'],
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: false }
      )
    end

    # @param [Hash] runtime_manifest Runtime Manifest Hash to be interpolated
    # @return [Hash] A Deep copy of the interpolated manifest Hash
    def interpolate_runtime_manifest(runtime_manifest)
      ignored_subtrees = [
        ['addons', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'properties'],
        ['addons', Integer, 'jobs', Integer, 'consumes', String, 'properties'],
      ]

      # Deployment name is passed here as nil because we required all placeholders
      # in the runtime config to be absolute, except for the properties in addons
      interpolate(
        runtime_manifest,
        nil,
        { subtrees_to_ignore: ignored_subtrees, must_be_absolute_name: true }
      )
    end

    # @param [Object] provided_prop property value
    # @param [Object] default_prop property value
    # @param [String] type of property
    # @param [String] deployment_name
    # @param [Hash] options hash containing extra options when needed
    # @return [Object] either the provided_prop or the default_prop
    def prepare_and_get_property(provided_prop, default_prop, type, deployment_name, options = {})
      if provided_prop.nil?
        result = default_prop
      else
        if is_placeholder?(provided_prop)
          extracted_name = add_prefix_if_not_absolute(
            extract_placeholder_name(provided_prop),
            @director_name,
            deployment_name
          )

          if name_exists?(extracted_name)
            result = provided_prop
          else
            if default_prop.nil?
              case type
                when 'password'
                  generate_password(extracted_name)
                when 'certificate'
                  generate_certificate(extracted_name, options)
              end
              result = provided_prop
            else
              result = default_prop
            end
          end
        else
          result = provided_prop
        end
      end
      result
    end

    private

    def get_value_for_name(name)
      response = @config_server_http_client.get(name)

      if response.kind_of? Net::HTTPOK
        response_body = JSON.parse(response.body)
        return response_body['value']
      elsif response.kind_of? Net::HTTPNotFound
        raise Bosh::Director::ConfigServerMissingNames, "Failed to load placeholder name '#{name}' from the config server"
      else
        raise Bosh::Director::ConfigServerUnknownError, "Unknown config server error: #{response.code}  #{response.message.dump}"
      end
    end

    def name_exists?(name)
      begin
        returned_name = get_value_for_name(name)
        !!returned_name
      rescue Bosh::Director::ConfigServerMissingNames
        false
      end
    end

    def fetch_names_values(placeholders, deployment_name, must_be_absolute_name)
      missing_names = []
      config_values = {}

      validate_absolute_names(placeholders) if must_be_absolute_name

      placeholders.each do |placeholder|
        name = add_prefix_if_not_absolute(
          extract_placeholder_name(placeholder),
          @director_name,
          deployment_name
        )

        begin
          config_values[placeholder] = get_value_for_name(name)
        rescue Bosh::Director::ConfigServerMissingNames
          missing_names << name
        end
      end

      [config_values, missing_names]
    end

    def generate_password(name)
      request_body = {
        'type' => 'password'
      }

      response = @config_server_http_client.post(name, request_body)

      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error on generating password: #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerPasswordGenerationError, "Config Server failed to generate password for '#{name}'"
      end
    end

    def generate_certificate(name, options)
      dns_record_names = options[:dns_record_names]
      request_body = {
        'type' => 'certificate',
        'parameters' => {
          'common_name' => dns_record_names.first,
          'alternative_names' => dns_record_names
        }
      }

      response = @config_server_http_client.post(name, request_body)

      unless response.kind_of? Net::HTTPSuccess
        @logger.error("Config server error on generating certificate: #{response.code}  #{response.message}. Request body sent: #{request_body}")
        raise Bosh::Director::ConfigServerCertificateGenerationError, "Config Server failed to generate certificate for '#{name}'"
      end
    end

    def validate_absolute_names(placeholders)
      non_absolute_names = placeholders.inject([]) do |memo, placeholder|
        name = extract_placeholder_name(placeholder)
        memo << name unless name.start_with?('/')
        memo
      end
      raise Bosh::Director::ConfigServerIncorrectNameSyntax, 'Names must be absolute path: ' + non_absolute_names.join(',') unless non_absolute_names.empty?
    end
  end

  class DisabledClient
    def interpolate(src, deployment_name, options={})
      Bosh::Common::DeepCopy.copy(src)
    end

    def interpolate_deployment_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def interpolate_runtime_manifest(manifest)
      Bosh::Common::DeepCopy.copy(manifest)
    end

    def prepare_and_get_property(manifest_provided_prop, default_prop, type, deployment_name, options = {})
      manifest_provided_prop.nil? ? default_prop : manifest_provided_prop
    end
  end
end
