# Copyright (c) 2009-2012 VMware, Inc.

require "atmos"
require "uri"
require "json"

module Bosh
  module Blobstore
    class AtmosBlobstoreClient < BaseClient
      SHARE_URL_EXP = "1893484800" # expires on 2030 Jan-1

      def initialize(options)
        super(options)
        @atmos_options = {
          :url => @options[:url],
          :uid => @options[:uid],
          :secret => @options[:secret]
        }
        @tag = @options[:tag]
        @http_client = HTTPClient.new
        # TODO: Remove this line once we get the proper certificate for atmos
        @http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      def atmos_server
        unless @atmos_options[:secret]
          raise "Atmos password is missing (read-only mode)"
        end
        @atmos ||= Atmos::Store.new(@atmos_options)
      end

      def create_file(file)
        obj_conf = {:data => file, :length => File.size(file.path)}
        obj_conf[:listable_metadata] = {@tag => true} if @tag
        object_id = atmos_server.create(obj_conf).aoid
        encode_object_id(object_id)
      end

      def get_file(object_id, file)
        object_info = decode_object_id(object_id)
        oid = object_info["oid"]
        sig = object_info["sig"]

        url = @atmos_options[:url] + "/rest/objects/#{oid}?uid=" +
              URI::escape(@atmos_options[:uid]) +
              "&expires=#{SHARE_URL_EXP}&signature=#{URI::escape(sig)}"

        response = @http_client.get(url) do |block|
          file.write(block)
        end

        if response.status != 200
          raise BlobstoreError, "Could not fetch object, %s/%s" %
            [response.status, response.content]
        end
      end

      def delete(object_id)
        object_info = decode_object_id(object_id)
        oid = object_info["oid"]
        atmos_server.get(:id => oid).delete
      rescue Atmos::Exceptions::NoSuchObjectException => e
        raise NotFound, "Atmos object '#{object_id}' not found"
      end

      private

      def decode_object_id(object_id)
        begin
          object_info = JSON.load(Base64.decode64(URI::unescape(object_id)))
        rescue JSON::ParserError => e
          raise BlobstoreError, "Failed to parse object_id. " +
            "Please try updating the release"
        end

        if !object_info.kind_of?(Hash) || object_info["oid"].nil? ||
            object_info["sig"].nil?
          raise BlobstoreError, "Invalid object_id (#{object_id})"
        end
        object_info
      end

      def encode_object_id(object_id)
        hash_string = "GET" + "\n" + "/rest/objects/" + object_id + "\n" +
                      @atmos_options[:uid] + "\n" + SHARE_URL_EXP
        secret = Base64.decode64(@atmos_options[:secret])
        sig = HMAC::SHA1.digest(secret, hash_string)
        signature = Base64.encode64(sig.to_s).chomp
        json = JSON.dump(:oid => object_id, :sig => signature)
        URI::escape(Base64.encode64(json))
      end
    end
  end
end
