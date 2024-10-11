module Support
  module StringHelpers
    def strip_heredoc(str)
      min = str.scan(/^[ \t]*(?=\S)/).min || ''
      indent = min.size || 0
      str.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end

RSpec.configure do |config|
  config.include(Support::StringHelpers)
end
