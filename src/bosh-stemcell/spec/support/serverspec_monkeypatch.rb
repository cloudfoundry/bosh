require 'serverspec'

# `example` method monkey path
unless SpecInfra::VERSION == '1.15.0'
  raise "Unexpected Specinfra version #{SpecInfra::VERSION}"
end

# Exec monkey path
require 'monkeypatch/serverspec/backend/exec'
include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS
