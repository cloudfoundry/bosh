require 'openssl'
require 'digest/sha1'
require 'base64'
require 'securerandom'
require 'open3'
require 'json'

module Bosh::Blobstore
  class AzurestoragecliBlobstoreClient < BaseClient
    # Blobstore client for azure storage account, using azure-storage-cli Go version
    # @param [Hash] options azure storage account connection options
    # @option options [Symbol] account_name
    #   key that is applied before the object is sent to azure storage account
    # @option options [Symbol, optional] account_key
    # @option options [Symbol, optional] container_name
    # @option options [Symbol] azure_storage_cli_path
    #   path to azure-storage-cli binary
    # @option options [Symbol, optional] azure_storage_cli_config_path
    #   path to store configuration files
    def initialize(options)
      super(options)

      @azure_storage_cli_path = @options.fetch(:azure_storage_cli_path)

      unless Kernel.system(@azure_storage_cli_path.to_s, '--v', out: '/dev/null', err: '/dev/null')
        raise BlobstoreError, 'Cannot find azure-storage-cli executable. Please specify azure_storage_cli_path parameter'
      end

      @azure_storage_cli_options = {
        "account_name": @options[:account_name],
        "container_name": @options[:container_name],
        "account_key": @options[:account_key]
      }

      @azure_storage_cli_options.reject! { |_k, v| v.nil? }

      @config_file = write_config_file(@azure_storage_cli_options, @options.fetch(:azure_storage_cli_config_path, nil))
    end

    def redacted_credential_properties_list
      %w[account_key]
    end

    def encryption_headers; end

    def encryption?
      false
    end

    def put_headers
      {
        'x-ms-blob-type' => 'blockblob'
      }
    end

    def put_headers?
      true
    end

    protected

    # @param [File] file file to store in az storage account
    def create_file(object_id, file)
      object_id ||= generate_object_id
      path = file.path

      store_in_azure_storage(path, full_oid_path(object_id))

      object_id
    end

    # @param [String] object_id object id to retrieve
    # @param [File] file file to store the retrieved object in
    def get_file(object_id, file)
      begin
        out, err, status = Open3.capture3(@azure_storage_cli_path.to_s, '-c', @config_file.to_s, 'get', object_id.to_s, file.path.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      return if status.success?

      raise NotFound, "Blobstore object '#{object_id}' not found" if err =~ /NoSuchKey/

      raise BlobstoreError, "Failed to download azure storage account object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'"
    end

    # @param [String] object_id object id to delete
    def delete_object(object_id)
      begin
        out, err, status = Open3.capture3(@azure_storage_cli_path.to_s, '-c', @config_file.to_s, 'delete', object_id.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to delete az storage account object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def object_exists?(object_id)
      begin
        out, err, status = Open3.capture3(@azure_storage_cli_path.to_s, '-c', @config_file.to_s, 'exists', object_id.to_s)
        return true if status.exitstatus.zero?
        return false if status.exitstatus == 3
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to check existence of az storage account object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def sign_url(object_id, verb, duration)
      begin
        out, err, status = Open3.capture3(
          @azure_storage_cli_path.to_s,
          '-c',
          @config_file.to_s,
          'sign',
          object_id.to_s,
          verb.to_s,
          duration.to_s,
        )
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end

      return out if status.success?

      raise BlobstoreError, "Failed to sign url, code #{status.exitstatus}, output: '#{out}', error: '#{err}'"
    end

    def required_credential_properties_list
      %w[account_key]
    end

    # @param [String] path path to file which will be stored in az storage account
    # @param [String] oid object id
    # @return [void]
    def store_in_azure_storage(path, oid)
      begin
        out, err, status = Open3.capture3(@azure_storage_cli_path.to_s, '-c', @config_file.to_s, 'put', path.to_s, oid.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to create azure storage account object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def full_oid_path(object_id)
      @options[:folder] ? @options[:folder] + '/' + object_id : object_id
    end
  end
end
