require 'stringio'

module Bosh::Cli::TaskTracking
  class SmartWhitespacePrinter
    VALID_SEPARATORS = [:line_around, :line_before, :before, :none].freeze

    SPACE_BETWEEN_LAST_SEP_AND_SEP = {
      [:line_around, :line_around] => "\n\n",
      [:line_around, :line_before] => "\n\n",
      [:line_around, :before] => "\n\n",
      [:line_around, :none]   => "\n\n",

      [:line_before, :line_around] => "\n\n",
      [:line_before, :line_before] => "\n\n",
      [:line_before, :before] => "\n",
      [:line_before, :none]   => nil,

      [:before, :line_around] => "\n\n",
      [:before, :line_before] => "\n\n",
      [:before, :before] => "\n",
      [:before, :none]   => nil,

      [:none, :line_around] => "\n\n",
      [:none, :line_before] => "\n\n",
      [:none, :before] => "\n",
      [:none, :none]   => nil,
    }.freeze

    def initialize
      @buffer = StringIO.new
      @last_sep = :start
    end

    def print(separator, msg)
      unless VALID_SEPARATORS.include?(separator)
        raise ArgumentError, "Unknown separator #{separator.inspect}"
      end

      space = SPACE_BETWEEN_LAST_SEP_AND_SEP[[@last_sep, separator]]
      @buffer.print(space) if space

      @last_sep = separator
      @buffer.print(msg)
    end

    def output
      @buffer.string.tap { @buffer.string = '' }
    end

    def finish
      if VALID_SEPARATORS.include?(@last_sep)
        @buffer.print("\n")
      end
    end
  end
end
