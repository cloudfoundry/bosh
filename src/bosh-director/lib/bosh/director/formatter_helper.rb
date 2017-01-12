module Bosh::Director
  class FormatterHelper

    # @param [String] src Source string to be indented
    # @param [Hash] options
    #   - [String] :indent_char to indent with, defaults to a space
    #   - [Integer] :indent_by how many spaces to indent, defaults to 1
    # @return [String] formatted string
    def indent_string(src, options={})
      indent_char = options.fetch(:indent_char, ' ')
      indent_by = options.fetch(:indent_by, 1)

      src.gsub(/([^\n]*)(\n|$)/) do |match|
        last_iteration = ($1 == '' && $2 == '')
        line = ''
        line << (indent_char * indent_by) unless last_iteration
        line << $1
        line << $2
        line
      end
    end

    # @param [String] header header to be added on string
    # @param [String] body string to be added after header
    # @param [Hash] options
    #   - [String] :indent_char to indent with, defaults to a space
    #   - [Integer] :indent_by how many spaces to indent, defaults to 1
    # @return [String] formatted string
    def prepend_header_and_indent_body(header, body, options={})
      indented_body = indent_string(body, options)
      indented_body.prepend("#{header}\n")
    end
  end
end
