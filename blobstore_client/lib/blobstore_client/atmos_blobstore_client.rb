require "atmos"

module Bosh
  module Blobstore
    class AtmosBlobstoreClient < BaseClient

      def initialize(options)
        @atmos_options = {
          :url => options[:url],
          :uid => options[:uid],
          :secret => options[:secret]
        }
        @tag = options[:tag]
      end

      def atmos_server
        @atmos ||= Atmos::Store.new(@atmos_options)
      end

      def create_file(file)
        obj_conf = {:data => file, :length => File.size(file.path)}
        obj_conf[:listable_metadata] = {@tag => true} if @tag
        atmos_server.create(obj_conf).aoid
      end

      def get_file(object_id, file)
        begin
          obj = atmos_server.get(object_id)
        rescue Atmos::Exceptions::NoSuchObjectException => e
          raise NotFound, "Atmos object '#{object_id}' not found"
        end
        obj.data_as_stream do |chunk|
          file.write(chunk)
        end
      end

      def delete(object_id)
        begin
          obj = atmos_server.get(object_id)
        rescue Atmos::Exceptions::NoSuchObjectException => e
          raise NotFound, "Atmos object '#{object_id}' not found"
        end
        obj.delete
      end

    end
  end
end
