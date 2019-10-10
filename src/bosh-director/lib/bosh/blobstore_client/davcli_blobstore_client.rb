require 'open3'
require 'securerandom'
require 'json'

module Bosh::Blobstore
  class DavcliBlobstoreClient < BaseClient
    def initialize(options)
      super(options)
      @davcli_path = @options.fetch(:davcli_path)
      unless Kernel.system("#{@davcli_path}", "-v", out: "/dev/null", err: "/dev/null")
        raise BlobstoreError, "Cannot find davcli executable. Please specify davcli_path parameter"
      end

      @davcli_options = {
        user: @options[:user],
        password: @options[:password],
        endpoint: @options[:endpoint],
        secret: @options[:secret],
        tls: @options[:tls]
      }
      @davcli_config_path = @options.fetch(:davcli_config_path, nil)
      @config_file_path = write_config_file(@davcli_config_path)
    end

    protected

    def get_file(id, file)
      begin
        out, err, status = Open3.capture3("#{@davcli_path}", '-c', "#{@config_file_path}", 'get', "#{id}", "#{file.path}")
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end

      if !status.success?
        if out =~/404 Not Found/
          raise NotFound, "Blobstore object '#{id}' not found"
        end

        raise BlobstoreError, "Failed to download blob, code #{status.exitstatus}, output: '#{out}', error: '#{err}'"
      end
    end

    def create_file(object_id, file)
      object_id ||= generate_object_id
      # in Ruby 1.8 File doesn't respond to :path
      path = file.respond_to?(:path) ? file.path : file

      store_in_webdav(path, full_oid_path(object_id))

      object_id
    end

    def object_exists?(object_id)
      begin
        out, err, status = Open3.capture3("#{@davcli_path}", '-c', "#{@config_file_path}", 'exists', "#{object_id}")
        if status.exitstatus == 0
          return true
        end
        if status.exitstatus == 3
          return false
        end
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to check existence of blob, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def delete_object(object_id)
      begin
        out, err, status = Open3.capture3("#{@davcli_path}", '-c', "#{@config_file_path}", 'delete', "#{object_id}")
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to delete blob, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def sign_url(object_id, verb, duration)
      begin
        out, err, status = Open3.capture3("#{@davcli_path}", '-c', "#{@config_file_path}", 'sign', "#{object_id}", "#{verb}", "#{duration}")
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to sign url, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?

      out
    end

    def credential_properties_list
      %w[user password secret]
    end

    def store_in_webdav(content_path, server_path)
      begin
        out, err, status = Open3.capture3("#{@davcli_path}", '-c', "#{@config_file_path}", 'put', "#{content_path}", "#{server_path}")
      rescue Exception => e
        raise BlobstoreError, e.inspect
      end
      raise BlobstoreError, "Failed to upload blob, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
    end

    def full_oid_path(object_id)
      @options[:folder] ?  @options[:folder] + '/' + object_id : object_id
    end

    def write_config_file(config_file_dir = nil)
      config_file_dir = Dir.tmpdir unless config_file_dir
      Dir.mkdir(config_file_dir) unless File.exists?(config_file_dir)
      random_name = "davcli-blobstore-config-#{SecureRandom.uuid}"
      config_file = File.join(config_file_dir, random_name)
      config_data = JSON.dump(@davcli_options)
      File.open(config_file, 'w', 0600) { |file| file.write(config_data) }
      config_file
    end
  end
end
