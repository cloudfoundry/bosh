require 'spec_helper'

describe 'cli: stemcell', type: :integration do
  with_reset_sandbox_before_each

  it 'verifies a sample valid stemcell', no_reset: true do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    success = regexp("#{stemcell_filename}' is a valid stemcell")
    expect(bosh_runner.run("verify stemcell #{stemcell_filename}")).to match(success)
  end

  it 'points to an error when verifying an invalid stemcell', no_reset: true do
    stemcell_filename = spec_asset('stemcell_invalid_mf.tgz')
    failure = regexp("`#{stemcell_filename}' is not a valid stemcell")
    expect(bosh_runner.run("verify stemcell #{stemcell_filename}", failure_expected: true)).to match(failure)
  end

  # ~65s (possibly includes sandbox start)
  it 'can upload a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    target_and_login
    out = bosh_runner.run("upload stemcell #{stemcell_filename}")
    expect(out).to match /Stemcell uploaded and created/

    out = bosh_runner.run('stemcells')
    expect(out).to match /stemcells total: 1/i
    expect(out).to match /ubuntu-stemcell.+1/
    expect(out).to match regexp(expected_id.to_s)

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
  end

  # ~40s
  it 'can delete a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    target_and_login
    out = bosh_runner.run("upload stemcell #{stemcell_filename}")
    expect(out).to match /Stemcell uploaded and created/

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
    out = bosh_runner.run('delete stemcell ubuntu-stemcell 1')
    expect(out).to match /Deleted stemcell `ubuntu-stemcell\/1'/
    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).not_to be_exists(stemcell_path)
  end

  context 'when stemcell is in use by a deployment' do
    it 'refuses to delete it' do
      deploy_simple
      results = bosh_runner.run('delete stemcell ubuntu-stemcell 1', failure_expected: true)
      expect(results).to match %r{Stemcell `ubuntu-stemcell/1' is still in use by: simple}
    end
  end

  describe 'uploading a stemcell that already exists' do
    context 'when the stemcell is local' do
      let(:local_stemcell_path) { spec_asset('valid_stemcell.tgz') }

      context 'when using the --skip-if-exists flag' do
        it 'tells the user and does not exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          results = bosh_runner.run("upload stemcell #{local_stemcell_path} --skip-if-exists", failure_expected: false)
          expect(results).to match %r{Stemcell `ubuntu-stemcell/1' already exists. Skipping upload.}
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          results = bosh_runner.run("upload stemcell #{local_stemcell_path}", failure_expected: true)
          expect(results).to match(%r{Stemcell `ubuntu-stemcell/1' already exists. Increment the version if it has changed.})
        end
      end
    end

    context 'when the stemcell is remote' do
      let(:remote_stemcell_url) { 'http://localhost:9292/valid_stemcell.tgz' }

      let(:webserver) do
        asset_root = spec_asset('')
        Bosh::Dev::Sandbox::Service.new(%W(rackup -b run(Rack::Directory.new('#{asset_root}'))), {}, Logger.new(STDOUT))
      end
      before { webserver.start }
      after { webserver.stop }

      context 'when using the --skip-if-exists flag' do
        it 'tells the user and does not exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          results = bosh_runner.run("upload stemcell #{remote_stemcell_url} --skip-if-exists", failure_expected: false)
          expect(results).to match %r{Stemcell at #{remote_stemcell_url} already exists.}
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          bosh_runner.run("upload stemcell #{remote_stemcell_url}", failure_expected: true)
        end
      end
    end
  end
end
