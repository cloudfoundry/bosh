module Bosh::Cli
  class CommandHandler

    # @return [Array]
    attr_reader :keywords

    # @return [String]
    attr_reader :usage

    # @return [String]
    attr_reader :desc

    # @return [Bosh::Cli::Runner]
    attr_accessor :runner

    attr_reader :options

    # @param [Class] klass
    # @param [UnboundMethod] method
    # @param [String] usage
    # @param [String] desc
    def initialize(klass, method, usage, desc, options = [])
      @klass = klass
      @method = method
      @usage = usage
      @desc = desc

      @options = options

      @hints = []
      @keywords = []

      @parser = OptionParser.new
      @runner = nil
      extract_keywords
    end

    # Run handler with provided args
    # @param [Array] args
    # @return [Integer] Command exit code
    def run(args, extra_options = {})
      command = @klass.new(@runner)

      @options.each do |(name, arguments)|
        @parser.on(name, *arguments) do |value|
          command.add_option(format_option_name(name), value)
        end
      end

      extra_options.each_pair do |name, value|
        command.add_option(format_option_name(name), value)
      end

      args = parse_options(args)

      begin
        command.send(@method.name, *args)
        command.exit_code
      rescue ArgumentError => ex
        err("#{ex.message}.\n\nUsage: #{usage_with_params}")
      end
    end

    def usage_with_params
      result = [@usage]
      @method.parameters.each do |parameter|
        next if parameter.size < 2
        kind, name = parameter
        if kind == :opt
          result << "[<#{name}>]"
        elsif kind == :req
          result << "<#{name}>"
        end
      end

      @options.each do |(name, _)|
        result << "[#{name}]"
      end

      result.join(" ")
    end

    def has_options?
      @options.size > 0
    end

    def options_summary
      result = []
      padding = 5

      margin = @options.inject(0) do |max, (name, _)|
        [max, name.size].max
      end

      @options.each do |(name, desc)|
        desc = desc.select { |word| word.is_a?(String) }
        column_width = terminal_width - padding - margin

        result << name.ljust(margin).make_yellow + " " +
          desc.join(" ").columnize(
            column_width, [margin + 1, name.size + 1].max)
      end

      result.join("\n")
    end

    # @param [Array] args Arguments to parse
    def parse_options(args)
      @parser.parse!(args)
    end

    private

    def format_option_name(name)
      case name
      when Symbol
        name
      when String
        name.split(/\s+/)[0].gsub(/^-*/, "").gsub("-", "_").to_sym
      else
        name
      end
    end

    def extract_keywords
      words = @usage.split(/\s+/)
      words.each do |word|
        break unless word.match(/^[a-z]/i)
        @keywords << word
      end
    end

  end
end
