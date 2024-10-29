require 'spec_helper'

describe 'upload stemcell with permissions', type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  director_client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}
  stemcells_upload_env = {'BOSH_CLIENT' => 'upload-stemcells-access', 'BOSH_CLIENT_SECRET' => 'stemcells-secret'}
  no_access_client_env = {'BOSH_CLIENT' => 'no-access', 'BOSH_CLIENT_SECRET' => 'secret'}

  def run_upload_stemcell_cmd(env)
    return bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}",
      client: env['BOSH_CLIENT'],
      client_secret: env['BOSH_CLIENT_SECRET'],
      return_exit_code: true,
      failure_expected: true
    )
  end

  it 'bosh.stemcells.upload should be able to upload stemcells to the director' do
    output, exit_code = run_upload_stemcell_cmd(stemcells_upload_env)

    expect(exit_code).to eq(0)
    expect(output).to include 'Save stemcell'
    expect(output).to include 'Succeeded'
  end

  it 'bosh.X.admin should be able to upload stemcells to the director' do
    output, exit_code = run_upload_stemcell_cmd(director_client_env)

    expect(exit_code).to eq(0)
    expect(output).to include 'Save stemcell'
    expect(output).to include 'Succeeded'
  end

  it 'no-access should not be able to upload stemcells to the director' do
    output, exit_code = run_upload_stemcell_cmd(no_access_client_env)

    expect(exit_code).to_not eq(0)
    expect(output).to_not include 'Save stemcell'
    expect(output).to_not include 'Succeeded'
  end
end
