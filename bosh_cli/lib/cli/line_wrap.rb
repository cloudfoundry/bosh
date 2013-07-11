module Bosh::Cli
  class LineWrap
    def initialize(width, left_margin = 0)
      @width = width
      @left_margin = left_margin
    end

    def wrap(string)
      paragraphs = string.split("\n")

      wrapped_paragraphs = paragraphs.map do |paragraph|
        indented = paragraph.start_with?('      ') ? '  ' : ''
        lines = break_into_lines(paragraph)
        lines = indent_lines(lines)

        indented + lines.join("\n")
      end

      wrapped_paragraphs.join("\n")
    end

    private

    attr_reader :width
    attr_reader :left_margin

    def break_into_lines(string)
      result = []
      buffer = ''

      string.split(' ').each do |word|
        if new_line_needed?(buffer, word)
          result << buffer
          buffer = word
        else
          buffer << ' ' unless buffer.empty?
          buffer << word
        end
      end
      result << buffer
    end

    def new_line_needed?(buffer, word)
      buffer.size + word.size > width
    end

    def indent_lines(lines)
      lines.map { |line| (' ' * left_margin) + line }
    end
  end
end