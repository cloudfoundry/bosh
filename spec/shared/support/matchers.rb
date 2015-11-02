module Support
  RSpec::Matchers.define :match_table do |expected|
    match do |actual|
      @actual = actual
      @expected = strip_heredoc(expected).strip

      @actual == @expected
    end

    failure_message do |actual|
      differ = RSpec::Support::Differ.new

      message = []
      message << "Expected table:"
      message << @expected
      message << "Actual table:"
      message << @actual
      message << "Diff:"
      message << differ.diff_as_string(@actual, @expected).to_s.strip

      message.join("\n\n")
    end
  end
end
