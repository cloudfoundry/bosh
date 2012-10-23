# Copyright (c) 2012 VMware, Inc.

require "bundler"
Bundler.setup(:default, :test)

require "rake"
require "rspec/core/rake_task"

SPEC_OPTS = %w(--format documentation --color)

desc "Run BAT tests"
RSpec::Core::RakeTask.new(:bat) do |t|
  t.pattern = %w[spec/env_spec.rb spec/bat/*_spec.rb]
  t.rspec_opts = SPEC_OPTS
end

namespace "bat" do

  desc "Verify BAT environment"
  RSpec::Core::RakeTask.new(:env) do |t|
    t.pattern = "spec/env_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

  desc "Run release tests"
  RSpec::Core::RakeTask.new(:release => :env) do |t|
    t.pattern = "spec/bat/release_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

  desc "Run deployment tests"
  RSpec::Core::RakeTask.new(:deployment => :env) do |t|
    t.pattern = "spec/bat/deployment_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

  desc "Run stemcell tests"
  RSpec::Core::RakeTask.new(:stemcell => :env) do |t|
    t.pattern = "spec/bat/stemcell_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

  desc "Run log tests"
  RSpec::Core::RakeTask.new(:log => :env) do |t|
    t.pattern = "spec/bat/log_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

  desc "Run job tests"
  RSpec::Core::RakeTask.new(:job => :env) do |t|
    t.pattern = "spec/bat/job_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

  desc "Run property tests"
  RSpec::Core::RakeTask.new(:property => :env) do |t|
    t.pattern = "spec/bat/property_spec.rb"
    t.rspec_opts = SPEC_OPTS
  end

end
