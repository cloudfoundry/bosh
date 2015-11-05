require 'spec_helper'

module Support
  module StringHelpers
    def strip_heredoc(str)
      indent = str.scan(/^[ \t]*(?=\S)/).min.size || 0
      str.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end

RSpec.configure do |config|
  config.include(Support::StringHelpers)
end
