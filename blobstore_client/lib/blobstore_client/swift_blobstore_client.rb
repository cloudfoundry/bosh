# Copyright (c) 2009-2012 VMware, Inc.

require "base64"
require "fog"
require "multi_json"
require "uri"
require "uuidtools"

module Bosh
  module Blobstore

    class SwiftBlobstoreClient < BaseClient

      # Blobstore client for Swift
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
        swift_options = {:provider => swift_provider}
        swift_options.merge!(@options[swift_provider.to_sym])
        swift = Fog::Storage.new(swift_options)

        container_name = @options[:container_name]
        @container = swift.directories.get(container_name)
        if @container.nil?
          raise NotFound, "Swift container '#{container_name}' not found"
        end
        @container
      end

      def create_file(file)
        object_id = generate_object_id
        object = container.files.create(:key => object_id,
                                        :body => file,
                                        :public => true)
        encode_object_id(object_id, object.public_url)
      rescue Exception => e
        raise BlobstoreError, "Failed to create object: #{e.message}"
      end

      def get_file(object_id, file)
        object_info = decode_object_id(object_id)
        if object_info["purl"]
          response = @http_client.get(object_info["purl"]) do |block|
            file.write(block)
          end
          if response.status != 200
            raise BlobstoreError, "Could not fetch object, %s/%s" %
                  [response.status, response.content]
          end
        else
          object = container.files.get(object_info["oid"]) do |block|
            file.write(block)
          end
          if object.nil?
            raise NotFound, "Swift object '#{object_id}' not found"
          end
        end
      rescue Exception => e
        raise BlobstoreError,
              "Failed to find object '#{object_id}': #{e.message}"
      end

      def delete(object_id)
        object_info = decode_object_id(object_id)
        object = container.files.get(object_info["oid"])
        if object.nil?
          raise NotFound, "Swift object '#{object_id}' not found"
        else
          object.destroy
        end
      rescue Exception => e
        raise BlobstoreError,
              "Failed to delete object '#{object_id}': #{e.message}"
      end

      private

      def generate_object_id
        UUIDTools::UUID.random_create.to_s
      end

      def encode_object_id(object_id, public_url = nil)
        json = MultiJson.encode({:oid => object_id, :purl => public_url})
        URI::escape(Base64.encode64(json))
      end

      def decode_object_id(object_id)
        begin
          object_info = MultiJson.decode(Base64.decode64(URI::unescape(object_id)))
        rescue MultiJson::DecodeError => e
          raise BlobstoreError, "Failed to parse object_id: #{e.message}"
        end

        if !object_info.kind_of?(Hash) || object_info["oid"].nil?
          raise BlobstoreError, "Invalid object_id: #{object_info.inspect}"
        end
        object_info
      end

      def validate_options(options)
        unless options.is_a?(Hash)
          raise "Invalid options format, Hash expected, #{options.class} given"
        end
        unless options.has_key?(:container_name)
          raise "Swift container name is missing"
        end
        unless options.has_key?(:swift_provider)
          raise "Swift provider is missing"
        end
        case options[:swift_provider]
          when "hp"
            unless options.has_key?(:hp)
              raise "HP options are missing"
            end
            unless options[:hp].is_a?(Hash)
              raise "Invalid HP options, Hash expected,
                    #{options[:hp].class} given"
            end
            unless options[:hp].has_key?(:hp_account_id)
              raise "HP account ID is missing"
            end
            unless options[:hp].has_key?(:hp_secret_key)
              raise "HP secret key is missing"
            end
            unless options[:hp].has_key?(:hp_tenant_id)
              raise "HP tenant ID is missing"
            end
          when "rackspace"
            unless options.has_key?(:rackspace)
              raise "Rackspace options are missing"
            end
            unless options[:rackspace].is_a?(Hash)
              raise "Invalid Rackspace options, Hash expected,
                    #{options[:rackspace].class} given"
            end
            unless options[:rackspace].has_key?(:rackspace_username)
              raise "Rackspace username is missing"
            end
            unless options[:rackspace].has_key?(:rackspace_api_key)
              raise "Rackspace API key is missing"
            end
          else
            raise "Swift provider #{options[:swift_provider]} not supported"
        end
      end

    end
  end
end