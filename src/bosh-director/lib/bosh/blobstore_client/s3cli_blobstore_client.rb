require 'openssl'
require 'digest/sha1'
require 'base64'
require 'securerandom'
require 'open3'
require 'json'

module Bosh::Blobstore
  class S3cliBlobstoreClient < BaseClient
    # Blobstore client for S3, using s3cli Go version
    # @param [Hash] options S3connection options
    # @option options [Symbol] bucket_name
    #   key that is applied before the object is sent to S3
    # @option options [Symbol, optional] access_key_id
    # @option options [Symbol, optional] secret_access_key
    # @option options [Symbol] s3cli_path
    #   path to s3cli binary
    # @option options [Symbol, optional] s3cli_config_path
    #   path to store configuration files
    # @note If access_key_id and secret_access_key are not present, the
    #   blobstore client operates in read only mode
    def initialize(options)
      super(options)

      @s3cli_path = @options.fetch(:s3cli_path)
      unless Kernel.system(@s3cli_path.to_s, '--v', out: '/dev/null', err: '/dev/null')
        raise BlobstoreError, 'Cannot find s3cli executable. Please specify s3cli_path parameter'
      end

      @s3cli_options = {
        bucket_name: @options[:bucket_name],
        use_ssl: @options.fetch(:use_ssl, true),
        host: @options[:host],
        host_style: @options.fetch(:host_style, false),
        port: @options[:port],
        region: @options[:region],
        ssl_verify_peer: @options.fetch(:ssl_verify_peer, true),
        credentials_source: @options.fetch(:credentials_source, 'none'),
        access_key_id: @options[:access_key_id],
        secret_access_key: @options[:secret_access_key],
        signature_version: @options[:signature_version],
        server_side_encryption: @options[:server_side_encryption],
        sse_kms_key_id: @options[:sse_kms_key_id],
        assume_role_arn: @options[:assume_role_arn],
        swift_auth_account: @options[:swift_auth_account],
        swift_temp_url_key: @options[:swift_temp_url_key],
        openstack_blobstore_type: @options[:openstack_blobstore_type]
      }

      @s3cli_options.reject! { |_k, v| v.nil? }

      if  @options[:access_key_id].nil? &&
          @options[:secret_access_key].nil?
        @options[:credentials_source] = 'none'
      end

      @config_file = write_config_file(@s3cli_options, @options.fetch(:s3cli_config_path, nil))
    end

    def redacted_credential_properties_list
      %w[access_key_id secret_access_key credentials_source]
    end

    def headers
      {}
    end

    protected

    # @param [File] file file to store in S3
    def create_file(object_id, file)
      object_id ||= generate_object_id
      # in Ruby 1.8 File doesn't respond to :path
      path = file.respond_to?(:path) ? file.path : file

      store_in_s3(path, full_oid_path(object_id))

      object_id
    end

    # @param [String] object_id object id to retrieve
    # @param [File] file file to store the retrived object in
    def get_file(object_id, file)
      begin
        out, err, status = Open3.capture3(@s3cli_path.to_s, '-c', @config_file.to_s, 'get', object_id.to_s, file.path.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      return if status.success?

      raise NotFound, "Blobstore object '#{object_id}' not found" if err =~ /NoSuchKey/

      raise BlobstoreError, "Failed to download S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'"
    end

    # @param [String] object_id object id to delete
    def delete_object(object_id)
      begin
        out, err, status = Open3.capture3(@s3cli_path.to_s, '-c', @config_file.to_s, 'delete', object_id.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to delete S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def object_exists?(object_id)
      begin
        out, err, status = Open3.capture3(@s3cli_path.to_s, '-c', @config_file.to_s, 'exists', object_id.to_s)
        return true if status.exitstatus.zero?
        return false if status.exitstatus == 3
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to check existence of S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def sign_url(object_id, verb, duration)
      begin
        out, err, status = Open3.capture3(
          @s3cli_path.to_s,
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
      return [] if @s3cli_options[:credentials_source] == 'env_or_profile'
      %w[access_key_id secret_access_key]
    end

    # @param [String] path path to file which will be stored in S3
    # @param [String] oid object id
    # @return [void]
    def store_in_s3(path, oid)
      begin
        out, err, status = Open3.capture3(@s3cli_path.to_s, '-c', @config_file.to_s, 'put', path.to_s, oid.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to create S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def full_oid_path(object_id)
      @options[:folder] ? @options[:folder] + '/' + object_id : object_id
    end
  end
end
