require 'set'

$cis_test_cases = Set.new

RSpec.configure do |config|
  config.before(:each) do |example|
    if example.full_description.include? "CIS-"
      $cis_test_cases += example.full_description.scan /CIS-(?:\d+\.?)+/
    end
  end
end
