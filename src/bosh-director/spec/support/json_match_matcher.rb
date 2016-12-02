# Usage:
#  something.should_receive(:send).with(json_match(eq('key' => 124)))
#  something.should_receive(:send).with(json_match(include('key' => 124)))
RSpec::Matchers.define :json_match do |matcher|
  match { |actual| matcher.matches?(JSON.parse(actual)) }
end
