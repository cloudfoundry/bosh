require_relative '../spec_helper'

describe 'upload releases with bosh.releases.upload permission', type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  it 'bosh.releases.upload can upload a release' do
    release_filename = spec_asset('test_release.tgz')

    _, exit_code = bosh_runner.run("upload-release #{release_filename}",
      client: 'upload-releases-access',
      client_secret: 'releases-secret',
      return_exit_code: true,
    )
    expect(exit_code).to eq(0)

    table_output = table(bosh_runner.run(
      'releases',
      client: 'test',
      client_secret: 'secret',
      json: true,
    ))
    expect(table_output).to include({'name' => 'test_release', 'version' => '1', 'commit_hash' => String})
    expect(table_output.length).to eq(1)
  end


  it 'is authenticated' do
    release_filename = spec_asset('test_release.tgz')

    _, exit_code = bosh_runner.run("upload-release #{release_filename}",
      client: 'no-access',
      client_secret: 'secret',
      return_exit_code: true,
      failure_expected: true
    )
    expect(exit_code).not_to eq(0)
  end
end
