require 'spec_helper'

describe 'export release', type: :integration do
  with_reset_sandbox_before_each

  before{
    target_and_login
    upload_cloud_config

    bosh_runner.run("upload release #{spec_asset('valid_release.tgz')}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    set_deployment({manifest_hash: Bosh::Spec::Deployments.minimal_manifest})
    deploy({})
  }

  it 'calls the director server' do
    out = bosh_runner.run("export release appcloud/0.1 centos-7/0000")
    expect(out).to match /Task ([0-9]+) done/
  end

  it 'returns an error when the release does not exist' do
    expect {
      bosh_runner.run("export release app/1 centos-7/0000")
    }.to raise_error(RuntimeError, /Error 30005: Bosh::Director::ReleaseNotFound/)
  end

  it 'returns an error when the release version does not exist' do
    expect {
      bosh_runner.run("export release appcloud/1 centos-7/0000")
    }.to raise_error(RuntimeError, /Error 30006: Bosh::Director::ReleaseVersionNotFound/)
  end
end