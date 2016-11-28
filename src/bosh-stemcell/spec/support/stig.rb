require 'set'

$stig_test_cases = Set.new

RSpec.configure do |config|
  config.before(:each) do |example|
    if example.full_description.include? "stig:"
      $stig_test_cases += example.full_description.scan /V-\d+/
    end
  end
end
