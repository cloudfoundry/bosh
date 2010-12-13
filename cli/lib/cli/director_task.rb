module Bosh
  module Cli
    class DirectorTask

      def initialize(api_client, task_id)
        @client   = api_client
        @task_id  = task_id
        @offset   = 0
        @buf      = ""
      end

      def state
        response_code, body = @client.get(state_uri)

        return "error" if response_code != 200
        return body
      end

      def output
        status, body, headers = @client.get(output_uri, nil, nil, { "Range" => "bytes=%d-" % [ @offset ] })

        if status == 206 && headers[:content_range].to_s =~ /bytes \d+-(\d+)\/\d+/
          @buf << body
          @offset = $1.to_i + 1
        else
          return nil
        end

        last_nl = @buf.rindex("\n")

        if !last_nl
          result = nil
        elsif last_nl != @buf.size - 1
          result = @buf[0..last_nl]
          @buf = @buf[last_nl+1..-1]
        else
          result = @buf
          @buf = ""
        end

        result
      end

      def flush_output
        out = @buf
        @buf = ""
        out + "\n"
      end

      private

      def state_uri
        "/tasks/%d" % [ @task_id ]
      end      

      def output_uri
        "/tasks/%d/output" % [ @task_id ]
      end

    end
  end
end

