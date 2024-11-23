require 'pty'
require 'timeout'
require 'blue-shell'

# BlueShell::Runner#send_keys
# BlueShell::Runner#exit_code
# BlueShell::Runner#output

module IntegrationSupport
  class MinimalRunner
    EXECUTION_TIMEOUT = 180

    def initialize(command)
      @stdout, pseudo_terminal = PTY.open
      system('stty raw', in: pseudo_terminal)
      read, @stdin = IO.pipe

      @pid = spawn({}, command, in: read, out: pseudo_terminal, err: pseudo_terminal)

      @expector = BufferedReaderExpector.new(@stdout)

      if block_given?
        yield self
      else
        wait_for_exit
      end
    end

    def expect(matcher)
      raise "Unsupported matcher: #{matcher.inspect}" if matcher.is_a?(Hash)

      @expector.expect(matcher)
    end

    def send_keys(text_to_send)
      @stdin.puts(text_to_send)
    end

    def exit_code
      return @code if @code

      code = nil
      begin
        Timeout.timeout(EXECUTION_TIMEOUT) do
          code = Process.waitpid2(@pid)[1]
        end
      rescue Timeout::Error
        raise ::Timeout::Error, "execution expired, output was:\n#{@expector.read_to_end}"
      end

      @code = numeric_exit_code(code)
    end

    alias_method :wait_for_exit, :exit_code

    def output
      @expector.output
    end

    private

    def numeric_exit_code(status)
      status.exitstatus
    rescue NoMethodError
      status
    end

    class BufferedReaderExpector
      attr_reader :output

      def initialize(out)
        @out = out
        @unused = ""
        @output = ""
      end

      def expect(pattern)
        case pattern
        when String
          pattern = Regexp.new(Regexp.quote(pattern))
        when Regexp
          # noop
        else
          raise TypeError, "unsupported pattern class: #{pattern.class}"
        end

        result, buffer = read_pipe(EXECUTION_TIMEOUT, pattern)

        @output << buffer

        result
      end

      def read_to_end
        _, buffer = read_pipe(0.01)
        @output << buffer
      end

      private

      def read_pipe(timeout, pattern = nil)
        buffer = ""
        result = nil
        position = 0

        while true
          if !@unused.empty?
            c = @unused.slice!(0).chr
          elsif output_ended?(timeout)
            @unused = buffer
            break
          else
            c = @out.getc.chr
          end

          # wear your flip-flops
          unless (c == "\e") .. (c == "m")
            if c == "\b"
              if position > 0 && buffer[position - 1] && buffer[position - 1].chr != "\n"
                position -= 1
              end
            else
              if buffer.size > position
                buffer[position] = c
              else
                buffer << c
              end

              position += 1
            end
          end

          if pattern && (matches = pattern.match(buffer))
            result = [buffer, *matches.to_a[1..-1]]
            break
          end
        end

        [result, buffer]
      end

      def output_ended?(timeout)
        !@out.wait_readable(timeout) || @out.eof?
      end
    end
  end
end
