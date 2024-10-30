require 'spec_helper'

describe 'stemcell uploads api', type: :integration do
  with_reset_sandbox_before_each
  let(:stemcell_filename) { asset_path('valid_stemcell.tgz') }
  let(:multiple_cpi_config) do
    cpi_config = SharedSupport::DeploymentManifestHelper.multi_cpi_config(current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI))
    cpi_config['cpis'][0]['properties'] = { 'formats' => ['other'] }
    cpi_config
  end

  it 'indicates when stemcells have not been presented to configured cpis' do
    bosh_runner.run("update-cpi-config #{yaml_file('multiple_cpi_config', multiple_cpi_config).path}")

    resp = send_director_post_request('/stemcell_uploads', '', JSON.dump(stemcell: { name: 'ubuntu-stemcell', version: '1' }))
    expect(resp.code).to eq('200')
    expect(resp.body).to eq('{"needed":true}')

    bosh_runner.run("upload-stemcell #{stemcell_filename}")

    resp = send_director_post_request('/stemcell_uploads', '', JSON.dump(stemcell: { name: 'ubuntu-stemcell', version: '1' }))
    expect(resp.code).to eq('200')
    expect(resp.body).to eq('{"needed":false}')

    bosh_runner.run('delete-stemcell ubuntu-stemcell/1')

    multiple_cpi_config['cpis'].pop
    bosh_runner.run("update-cpi-config #{yaml_file('multiple_cpi_config', multiple_cpi_config).path}")

    resp = send_director_post_request('/stemcell_uploads', '', JSON.dump(stemcell: { name: 'ubuntu-stemcell', version: '1' }))
    expect(resp.code).to eq('200')
    expect(resp.body).to eq('{"needed":true}')
  end
end
