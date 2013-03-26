require "rspec"
require "rspec/core/rake_task"

SPEC_OPTS = %w(--format documentation --color)

SPEC_OPTS << '--fail-fast' if (ENV['BAT_FAIL_FAST'] || "false").downcase == 'true'

desc "Run BAT tests"
RSpec::Core::RakeTask.new(:bat) do |t|
  cd 'bat'
  t.pattern = %w[spec/env_spec.rb spec/bat/*_spec.rb]
  t.rspec_opts = SPEC_OPTS
end

namespace "bat" do

  desc "Verify BAT environment"
  RSpec::Core::RakeTask.new(:env) do |t|
    cd 'bat'
    t.pattern = "spec/env_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end
end
