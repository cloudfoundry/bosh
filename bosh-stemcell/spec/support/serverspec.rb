require 'serverspec'

# `example` method monkey path
unless Specinfra::VERSION == '0.0.17'
  raise "Unexpected Specinfra version #{Specinfra::VERSION}"
end

RSpec.configure do |c|
  # RSpec 3.0 explicitly passes in example method into
  # before(:each) so we delete non-compatible before each
  # added in `lib/specinfra.rb`.
  c.hooks[:before][:each].pop

  # c.before do         # before
  c.before do |example| # after
    if respond_to?(:backend) && backend.respond_to?(:set_example)
      backend.set_example(example)
    end
  end
end

SpecInfra::Helper::Configuration.class_eval do
  # Rspec 3.0 removed `example`method but introduced `RSpec.current_example`
  def subject
    # example.metadata[:subject] = described_class             # before
    RSpec.current_example.metadata[:subject] = described_class # after
    build_configurations
    super
  end
end

SpecInfra::Backend::Exec.class_eval do
  alias_method :check_os_with_broken_ubuntu_detection, :check_os

  # SpecInfra does not properly detect lsb_release
  # so we have to correct family that is returned
  # Used to return 'Distributor ID:\tUbuntu\n' as family.
  def check_os
    result = check_os_with_broken_ubuntu_detection
    family = result[:family]
    if family.include?('Distributor ID:')
      result[:family] = family.split(/\s+/, 3).last.strip
    end
    result
  end
end

# Exec monkey path
require 'monkeypatch/serverspec/backend/exec'
include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS
