require 'spec_helper'

describe Bosh::Cli::LineWrap do
  let(:line_wrap) { Bosh::Cli::LineWrap.new(20) }
  let(:line_wrap_with_indent) { Bosh::Cli::LineWrap.new(20, 2) }

  it 'wraps long lines to the requested width' do
    result = line_wrap.wrap('hello this is a line that has quite a lot of words')
    expect(result).to eq "hello this is a line\nthat has quite a lot\nof words"
  end

  it 'adds a left margin when requested' do
    result = line_wrap_with_indent.wrap('hello this is a line that has quite a lot of words')
    expect(result).to eq "  hello this is a line\n  that has quite a lot\n  of words"
  end

  it 'preserves existing line breaks' do
    result = line_wrap.wrap("hello this is\n a line that has quite a lot of words")
    expect(result).to eq "hello this is\na line that has quite\na lot of words"
  end

  it 'preserves existing 6 character left margins (for outputing our CLI help (urgh))' do
    result = line_wrap.wrap("hello this is a line\n        that has quite a lot\n        of words")
    expect(result).to eq "hello this is a line\n  that has quite a lot\n  of words"
  end
end