# Copyright (c) 2009-2012 VMware, Inc.

require 'atmos'
require 'uri'
require 'multi_json'
require 'httpclient'

module Bosh
  module Blobstore
    class AtmosBlobstoreClient < BaseClient
      SHARE_URL_EXP = '1893484800' # expires on 2030 Jan-1

      def initialize(options)
        super(options)
        @atmos_options = {
          url: @options[:url],
          uid: @options[:uid],
          secret: @options[:secret]
        }
        @tag = @options[:tag]

        if @options[:unsupported]
          @atmos_options[:unsupported] = @options[:unsupported]
        end

        # Add proxy if ENV has the variable
        proxy = case URI.parse(@atmos_options[:url] || '').scheme
                  when 'https'
                    ENV['HTTPS_PROXY'] || ENV['https_proxy']
                  when 'http'
                    ENV['HTTP_PROXY'] || ENV['http_proxy']
                  else
                    nil
                end
        if proxy
          @atmos_options[:proxy] = proxy
          @http_client = HTTPClient.new(proxy: proxy)
        end
        @http_client ||= HTTPClient.new
        @http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      def atmos_server
        raise 'Atmos password is missing (read-only mode)' unless @atmos_options[:secret]

        @atmos ||= Atmos::Store.new(@atmos_options)
      end

      protected

      def create_file(id, file)
        raise BlobstoreError, 'Atmos does not support supplying the object id' if id
        obj_conf = { data: file, length: File.size(file.path) }
        obj_conf[:listable_metadata] = { @tag => true } if @tag
        object_id = atmos_server.create(obj_conf).aoid
        encode_object_id(object_id)
      end

      def get_file(object_id, file)
        object_info = decode_object_id(object_id)
        oid = object_info['oid']
        sig = object_info['sig']

        url = @atmos_options[:url] + "/rest/objects/#{oid}?uid=" +
          URI.escape(@atmos_options[:uid]) +
          "&expires=#{SHARE_URL_EXP}&signature=#{URI.escape(sig)}"

        response = @http_client.get(url) do |block|
          file.write(block)
        end

        if response.status != 200
          raise BlobstoreError, sprintf('Could not fetch object, %s/%s', [response.status, response.content])
        end
      end

      def delete_object(object_id)
        object_info = decode_object_id(object_id)
        oid = object_info['oid']
        atmos_server.get(id: oid).delete
      rescue Atmos::Exceptions::NoSuchObjectException
        raise NotFound, "Atmos object '#{object_id}' not found"
      end

      def object_exists?(object_id)
        atmos_server.get(id: object_id).exists?
      end

      private

      def decode_object_id(object_id)
        begin
          object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
        rescue MultiJson::DecodeError
          raise BlobstoreError, 'Failed to parse object_id. Please try updating the release'
        end

        if !object_info.kind_of?(Hash) || object_info['oid'].nil? ||
          object_info['sig'].nil?
          raise BlobstoreError, "Invalid object_id (#{object_id})"
        end
        object_info
      end

      def encode_object_id(object_id)
        hash_string = "GET\n/rest/objects/#{object_id}\n#{@atmos_options[:uid]}\n#{SHARE_URL_EXP}"
        secret = Base64.decode64(@atmos_options[:secret])
        sig = HMAC::SHA1.digest(secret, hash_string)
        signature = Base64.encode64(sig.to_s).chomp
        json = MultiJson.encode({ oid: object_id, sig: signature })
        URI.escape(Base64.encode64(json))
      end
    end
  end
end
