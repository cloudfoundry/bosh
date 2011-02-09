module Bosh
  module Cli
    class DirectorTask

      attr_accessor :offset

      def initialize(director, task_id)
        @director = director
        @task_id  = task_id
        @offset   = 0
        @buf      = ""
      end

      def state
        @director.get_task_state(@task_id)
      end

      def output
        body, new_offset = @director.get_task_output(@task_id, @offset)

        @buf << body if body

        if new_offset
          @offset = new_offset
        else
          return flush_output
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
        out.blank? ? nil : "#{out}\n"
      end

    end
  end
end

