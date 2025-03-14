require 'spec_helper'

describe Bosh::Director::FormatterHelper do
  subject { described_class.new }

  describe '#indent_string' do
    it 'indents string' do
      input = <<~INPUT
        Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      INPUT

      output = <<-EXPECTED
 Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
 Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
 Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      EXPECTED

      expect(subject.indent_string(input)).to eq output
    end

    it 'indents string with custom character' do
      input = <<~INPUT
        Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'

        Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      INPUT

      output = <<~EXPECTED
        .Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        .Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
        .
        .Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      EXPECTED

      expect(subject.indent_string(input, indent_char: '.')).to eq output
    end

    it 'indents string with custom indentation count' do
      input = <<~INPUT
        Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      INPUT

      output = <<-EXPECTED
    Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
    Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
    Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      EXPECTED

      expect(subject.indent_string(input, indent_by: 4)).to eq output
    end
  end

  describe '#prepend_header_and_indent_body' do
    it 'prepends header and indents string' do
      input = <<~INPUT
        Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      INPUT

      output = <<~EXPECTED
        I am a header
         Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
         Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
         Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      EXPECTED

      expect(subject.prepend_header_and_indent_body('I am a header', input)).to eq output
    end

    it 'respects indentation options string' do
      input = <<~INPUT
        Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
        Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      INPUT

      output = <<~EXPECTED
        I am a header
        ....Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
        ....Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
        ....Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
      EXPECTED

      expect(subject.prepend_header_and_indent_body('I am a header', input, indent_by: 4, indent_char: '.')).to eq output
    end
  end
end
