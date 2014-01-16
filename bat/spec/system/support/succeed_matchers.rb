RSpec::Matchers.define :succeed do |_|
  match do |actual|
    expect(actual.exit_status).to eq 0
  end

  failure_message_for_should do |actual|
    'expected command to exit with 0 but was ' +
      "#{actual.exit_status}. output was\n#{actual.output}"
  end
end

RSpec::Matchers.define :succeed_with do |expected|
  match do |actual|
    expect(actual.exit_status).to eq 0

    case expected
      when String
        expect(actual.output).to eq(expected)
      when Regexp
        # See https://www.relishapp.com/rspec/rspec-expectations/v/2-14/docs/
        # custom-matchers/define-matcher#matching-against-a-regular-expression
        expect(actual.output).to match_regex(expected)
      else
        raise ArgumentError, "don't know what to do with a #{expected.class}"
    end
  end

  failure_message_for_should do |actual|
    case expected
      when String
        what = 'be'
        exp = expected
      when Regexp
        what = 'match'
        exp = "/#{expected.source}/"
      else
        raise ArgumentError, "don't know what to do with a #{expected.class}"
    end

    'expected command to exit with 0 but was ' +
      "#{actual.exit_status}. expected output to " +
      "#{what} '#{exp}' but was\n#{actual.output}"
  end
end
