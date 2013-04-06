# Copyright (c) 2009-2012 VMware, Inc.
require 'sys/filesystem'
include Sys

module Bosh::Director
  module Api
    module ApiHelper
      READ_CHUNK_SIZE = 16384

      class DisposableFile < ::Rack::File
        def close
          FileUtils.rm_rf(self.path) if File.exists?(self.path)
        end
      end

      # Adapted from Sinatra::Base#send_file. There is one difference:
      # it uses DisposableFile instead of Rack::File.
      # DisposableFile gets removed on "close" call. This is primarily
      # meant to serve temporary files fetched from the blobstore.
      # We CANNOT use a Sinatra after filter, as the filter is called before
      # the contents of the file is sent to the client.
      def send_disposable_file(path, opts = {})
        if opts[:type] || !response['Content-Type']
          content_type opts[:type] || File.extname(path), :default => 'application/octet-stream'
        end

        disposition = opts[:disposition]
        filename    = opts[:filename]
        disposition = 'attachment' if disposition.nil? && filename
        filename    = path         if filename.nil?
        attachment(filename, disposition) if disposition

        last_modified opts[:last_modified] if opts[:last_modified]

        file      = DisposableFile.new nil
        file.path = path
        result    = file.serving env
        result[1].each { |k,v| headers[k] ||= v }
        headers['Content-Length'] = result[1]['Content-Length']
        halt opts[:status] || result[0], result[2]
      rescue Errno::ENOENT
        not_found
      end

      def json_encode(payload)
        Yajl::Encoder.encode(payload)
      end

      def json_decode(payload)
        Yajl::Parser.parse(payload)
      end

      def start_task
        task = yield
        unless task.kind_of?(Models::Task)
          raise "Block didn't return Task object"
        end
        redirect "/tasks/#{task.id}"
      end

      def check_available_disk_space(dir, size)
        begin
          stat = Sys::Filesystem.stat(dir)
          available_space = stat.block_size * stat.blocks_available
          available_space > size ? true : false
        rescue
          false
        end
      end

      def write_file(path, stream, chunk_size = READ_CHUNK_SIZE)
        buffer = ""
        File.open(path, "w") do |file|
          file.write(buffer) until stream.read(chunk_size, buffer).nil?
        end
      rescue SystemCallError => e
        raise SystemError, e.message
      end
    end
  end
end