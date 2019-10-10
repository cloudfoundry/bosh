require 'securerandom'
require 'open3'
require 'json'

module Bosh::Blobstore
  class GcscliBlobstoreClient < BaseClient
    EXIT_CODE_OBJECT_FOUND = 0
    EXIT_CODE_OBJECT_NOTFOUND = 3

    # Blobstore client for GCS, using bosh-gcscli binary
    # @param [Hash] options GCSconnection options
    # @option options [Symbol] bucket_name
    #   key that is applied before the object is sent to GCS
    # @option options [Symbol, optional] access_key_id
    # @option options [Symbol, optional] secret_access_key
    # @option options [Symbol] gcscli_path
    #   path to gcscli binary
    # @option options [Symbol, optional] gcscli_config_path
    #   path to store configuration files
    # @note If access_key_id and secret_access_key are not present, the
    #   blobstore client operates in read only mode
    def initialize(options)
      super(options)

      @gcscli_path = @options.fetch(:gcscli_path)
      unless Kernel.system(@gcscli_path.to_s, '--v', out: '/dev/null', err: '/dev/null')
        raise BlobstoreError, 'Cannot find gcscli executable. Please specify gcscli_path parameter'
      end

      @gcscli_options = {
        bucket_name: @options[:bucket_name],
        credentials_source: @options.fetch(:credentials_source, 'none'),
        json_key: @options[:json_key],
        encryption_key: @options[:encryption_key],
        storage_class: @options[:storage_class],
      }

      @gcscli_options.reject! { |_k, v| v.nil? }

      @config_file = write_config_file(@options.fetch(:gcscli_config_path, nil))
    end

    protected

    # @param [File] file file to store in GCS
    def create_file(object_id, file)
      object_id ||= generate_object_id

      store_in_gcs(file.path, full_oid_path(object_id))

      object_id
    end

    # @param [String] object_id object id to retrieve
    # @param [File] file file to store the retrived object in
    def get_file(object_id, file)
      begin
        out, err, status = Open3.capture3(@gcscli_path.to_s, '-c', @config_file.to_s, 'get', object_id.to_s, file.path.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end

      return if status.success?

      raise NotFound, "Blobstore object '#{object_id}' not found" if err =~ /object doesn't exist/

      raise BlobstoreError, "Failed to download GCS object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'"
    end

    # @param [String] object_id object id to delete
    def delete_object(object_id)
      begin
        out, err, status = Open3.capture3(@gcscli_path.to_s, '-c', @config_file.to_s, 'delete', object_id.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to delete GCS object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def object_exists?(object_id)
      begin
        out, err, status = Open3.capture3(@gcscli_path.to_s, '-c', @config_file.to_s, 'exists', object_id.to_s)
        return true if status.exitstatus == EXIT_CODE_OBJECT_FOUND
        return false if status.exitstatus == EXIT_CODE_OBJECT_NOTFOUND
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to check existence of GCS object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def sign_url(object_id, verb, duration)
      begin
        out, err, status = Open3.capture3(
          @gcscli_path.to_s,
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

    def credential_properties_list
      %w[json_key encryption_key credentials_source]
    end

    # @param [String] path path to file which will be stored in GCS
    # @param [String] oid object id
    # @return [void]
    def store_in_gcs(path, oid)
      begin
        out, err, status = Open3.capture3(@gcscli_path.to_s, '-c', @config_file.to_s, 'put', path.to_s, oid.to_s)
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to create GCS object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def full_oid_path(object_id)
      @options[:folder] ? @options[:folder] + '/' + object_id : object_id
    end

    def write_config_file(config_file_dir = nil)
      config_file_dir ||= Dir.tmpdir
      Dir.mkdir(config_file_dir) unless File.exist?(config_file_dir)
      random_name = "gcs_blobstore_config-#{SecureRandom.uuid}"
      config_file = File.join(config_file_dir, random_name)
      config_data = JSON.dump(@gcscli_options)

      File.open(config_file, 'w', 0o600) { |file| file.write(config_data) }
      config_file
    end
  end
end
