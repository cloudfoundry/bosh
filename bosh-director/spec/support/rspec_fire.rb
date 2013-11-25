require 'rspec/fire'

RSpec.configure do |config|
  config.include(RSpec::Fire)
end

RSpec::Fire.configure do |config|
  config.verify_constant_names = true
end

# Temporary until we get to RSpec3
module StricterStubbing
  # original method is found in rspec/fire.rb, RSpec::Fire::FireDoublable
  def stub(method_name)
    if method_name.is_a?(Hash)
      method_name.each_pair { |method_name, _| ensure_implemented(method_name) }
    else
      ensure_implemented(method_name)
    end
    super
  end

  # original method is found in rspec/mocks/test_double.rb, RSpec::Mocks::TestDouble
  def assign_stubs(stubs)
    stubs.each_pair { |method_name, _| ensure_implemented(method_name) }
    super
  end
end

RSpec::Fire::FireObjectDouble.class_eval do
  include StricterStubbing
end
