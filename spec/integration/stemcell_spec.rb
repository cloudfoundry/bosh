require 'spec_helper'

describe 'stemcell integrations' do
  include IntegrationExampleGroup

  context 'when stemcell is in use by a deployment' do
    it 'refuses to delete it' do
      deploy_simple
      results = run_bosh('delete stemcell ubuntu-stemcell 1', failure_expected: true)
      expect(results).to match %r{Stemcell `ubuntu-stemcell/1' is still in use by: simple}
    end
  end

  describe 'uploading a stemcell that already exists' do
    context 'when the stemcell is local' do
      let(:local_stemcell_path) { spec_asset('valid_stemcell.tgz') }

      context 'when using the --skip-if-exists flag' do
        it 'tells the user and does not exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          results = run_bosh("upload stemcell #{local_stemcell_path} --skip-if-exists", failure_expected: false)
          expect(results).to match %r{Stemcell `ubuntu-stemcell/1' already exists. Skipping upload.}
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          results = run_bosh("upload stemcell #{local_stemcell_path}", failure_expected: true)
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
          results = run_bosh("upload stemcell #{remote_stemcell_url} --skip-if-exists", failure_expected: false)
          expect(results).to match %r{Stemcell at #{remote_stemcell_url} already exists.}
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          deploy_simple # uploads the same stemcell "spec_asset('valid_stemcell.tgz')" used below
          run_bosh("upload stemcell #{remote_stemcell_url}", failure_expected: true)
        end
      end
    end
  end
end
