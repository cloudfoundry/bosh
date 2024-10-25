module Support
  RSpec::Matchers.define :match_output do |expected|
    def strip_heredoc(str)
      min = str.scan(/^[ \t]*(?=\S)/).min || ''
      indent = min.size || 0
      str.gsub(/^[ \t]{#{indent}}/, '')
    end

    match do |actual|
      @actual = actual.strip
      @expected = strip_heredoc(expected).strip

      @actual.include? @expected
    end

    failure_message do |_actual|
      differ = RSpec::Support::Differ.new

      message = []
      message << "Expected output:"
      message << @expected
      message << "Actual output:"
      message << @actual
      message << "Diff:"
      message << differ.diff_as_string(@actual, @expected).to_s.strip

      message.join("\n\n")
    end
  end
end
