require 'spec_helper'

describe 'blobs verification behavior', type: :integration do
  with_reset_sandbox_before_each

  it 'fails when job object is changed' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    prepare_for_deploy

    inspected_release = bosh_runner.run('inspect-release bosh-release/0+dev.1', json: true)
    foobar_row = JSON.parse(inspected_release)['Tables'][0]['Rows'].select { |job_row| job_row['job'] =~ %r{^foobar\/.*} }[0]

    File.open("#{current_sandbox.blobstore_storage_dir}/#{foobar_row['blobstore_id']}", 'w') { |f| f.write 'bad-data' }

    output, = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)

    expect(output).to match(/Expected stream to have digest '.+' but was '.+'/)
  end
end
