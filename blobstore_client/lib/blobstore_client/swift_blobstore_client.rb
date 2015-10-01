# Copyright (c) 2009-2012 VMware, Inc.

require 'base64'
require 'fog'
require 'multi_json'
require 'uri'
require 'httpclient'

module Bosh
  module Blobstore

    class SwiftBlobstoreClient < BaseClient

      # Blobstore client for OpenStack Swift
      # @param [Hash] options Swift BlobStore options
      # @option options [Symbol] container_name
      # @option options [Symbol] swift_provider
      def initialize(options)
        super(options)
        @http_client = HTTPClient.new
      end

      def container
        return @container if @container

        validate_options(@options)

        swift_provider = @options[:swift_provider]
        swift_options = { provider: swift_provider }
        swift_options.merge!(@options[swift_provider.to_sym])

        if swift_options.has_key?(:openstack_auth_url)
          unless swift_options[:openstack_auth_url].match(/\/tokens$/)
            swift_options[:openstack_auth_url] = swift_options[:openstack_auth_url] + '/tokens'
          end
        end

        swift = Fog::Storage.new(swift_options)

        container_name = @options[:container_name]
        @container = swift.directories.get(container_name)
        raise NotFound, "Swift container '#{container_name}' not found" if @container.nil?

        @container
      end

      protected

      def create_file(object_id, file)
        object_id ||= generate_object_id
        object = container.files.create(key: object_id, body: file)
        begin
          public_url = object.public_url
        rescue NotImplementedError
          public_url = nil
        end
        encode_object_id(object_id, public_url)
      rescue Exception => e
        raise BlobstoreError, "Failed to create object: #{e.message}"
      end

      def get_file(object_id, file)
        object_info = decode_object_id(object_id)
        if object_info['purl']
          response = @http_client.get(object_info['purl']) do |block|
            file.write(block)
          end
          if response.status != 200
            raise BlobstoreError, "Could not fetch object, #{response.status} #{response.content}"
          end
        else
          object = container.files.get(object_info['oid']) do |block|
            file.write(block)
          end
          raise NotFound, "Swift object '#{object_info['oid']}' not found" if object.nil?
        end
      rescue Exception => e
        raise BlobstoreError, "Failed to find object '#{object_id}': #{e.message}"
      end

      def delete_object(object_id)
        object_info = decode_object_id(object_id)
        object = container.files.get(object_info['oid'])

        raise NotFound, "Swift object '#{object_id}' not found" if object.nil?

        object.destroy
      rescue NotFound => e
        raise e
      rescue Exception => e
        raise BlobstoreError, "Failed to delete object '#{object_id}': #{e.message}"
      end

      def object_exists?(object_id)
        object_info = decode_object_id(object_id)
        object = container.files.head(object_info['oid'])
        object.nil? ? false : true
      rescue Exception => e
        raise BlobstoreError, "Failed to find object '#{object_id}': #{e.message}"
      end

      private

      def encode_object_id(object_id, public_url = nil)
        json = MultiJson.encode({ oid: object_id, purl: public_url })
        URI.escape(Base64.encode64(json))
      end

      def decode_object_id(object_id)
        begin
          object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
        rescue MultiJson::DecodeError
          object_info = {}
          object_info['oid'] = object_id
        end

        raise BlobstoreError, "Invalid object_id: #{object_info.inspect}" if !object_info.kind_of?(Hash) || object_info['oid'].nil?

        object_info
      end

      def validate_options(options)
        raise "Invalid options format, Hash expected, #{options.class} given" unless options.is_a?(Hash)
        raise 'Swift container name is missing' unless options.has_key?(:container_name)
        raise 'Swift provider is missing' unless options.has_key?(:swift_provider)
        case options[:swift_provider]
          when 'hp'
            raise 'HP options are missing' unless options.has_key?(:hp)
            raise "Invalid HP options, Hash expected, #{options[:hp].class} given" unless options[:hp].is_a?(Hash)
            raise 'HP access key is missing' unless options[:hp].has_key?(:hp_access_key)
            raise 'HP secret key is missing' unless options[:hp].has_key?(:hp_secret_key)
            raise 'HP tenant ID is missing' unless options[:hp].has_key?(:hp_tenant_id)
            raise 'HP availability zone is missing' unless options[:hp].has_key?(:hp_avl_zone)
          when 'openstack'
            raise 'OpenStack options are missing' unless options.has_key?(:openstack)
            raise "Invalid OpenStack options, Hash expected, #{options[:openstack].class} given" unless options[:openstack].is_a?(Hash)
            raise 'OpenStack authorization URL is missing' unless options[:openstack].has_key?(:openstack_auth_url)
            raise 'OpenStack user name is missing' unless options[:openstack].has_key?(:openstack_username)
            raise 'OpenStack API key is missing' unless options[:openstack].has_key?(:openstack_api_key)
            raise 'OpenStack tenant is missing' unless options[:openstack].has_key?(:openstack_tenant)
          when 'rackspace'
            raise 'Rackspace options are missing' unless options.has_key?(:rackspace)
            raise "Invalid Rackspace options, Hash expected, #{options[:rackspace].class} given" unless options[:rackspace].is_a?(Hash)
            raise 'Rackspace username is missing' unless options[:rackspace].has_key?(:rackspace_username)
            raise 'Rackspace API key is missing' unless options[:rackspace].has_key?(:rackspace_api_key)
          else
            raise "Swift provider #{options[:swift_provider]} not supported"
        end
      end

    end
  end
end