# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    module ApiHelper
      READ_CHUNK_SIZE = 16384

      class DisposableStaticFile < ::Sinatra::Base::StaticFile
        def close
          super
          FileUtils.rm_rf(self.path) if File.exists?(self.path)
        end
      end

      # Adapted from Sinatra::Base#send_file. There are two differences:
      # it doesn't support range queries
      # it uses DisposableStaticFile instead of Sinatra::Base::StaticFile.
      # DisposableStaticFile gets removed on "close" call. This is primarily
      # meant to serve temporary files fetched from the blobstore.
      def send_disposable_file(path, opts = {})
        stat = File.stat(path)
        last_modified(opts[:last_modified] || stat.mtime)

        if opts[:type] or not response["Content-Type"]
          content_type(opts[:type] || File.extname(path),
                       :default => "application/octet-stream")
        end

        if opts[:disposition] == "attachment" || opts[:filename]
          attachment opts[:filename] || path
        elsif opts[:disposition] == "inline"
          response["Content-Disposition"] = "inline"
        end

        file_length = opts[:length] || stat.size
        sf = DisposableStaticFile.open(path, "rb")

        response["Content-Length"] ||= file_length.to_s
        halt sf
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

      def write_file(path, stream, chunk_size = READ_CHUNK_SIZE)
        buffer = ""
        File.open(path, "w") do |file|
          file.write(buffer) until stream.read(chunk_size, buffer).nil?
        end
      end
    end
  end
end