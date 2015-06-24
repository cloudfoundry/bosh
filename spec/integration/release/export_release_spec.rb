require 'spec_helper'

describe 'export release', type: :integration do
  with_reset_sandbox_before_each

  it 'export release calls the director server' do
    target_and_login
    upload_cloud_config
    set_deployment({})

    out = bosh_runner.run("export release release/1 centos-7/0000")
    expect(out).to match /Task ([0-9]+) done/
  end
end