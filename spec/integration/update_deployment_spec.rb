require 'spec_helper'

describe 'update deployment', type: :integration do
  with_reset_sandbox_before_each

  before{
    target_and_login
    upload_cloud_config

    bosh_runner.run("upload release #{spec_asset('valid_release_with_dependencies.tgz')}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    set_deployment({manifest_hash: Bosh::Spec::Deployments.manifest_with_jobs})
    # deploy({})
  }

  it 'deploy release successfully' do
    bosh_runner.run("deploy")
  end
end
