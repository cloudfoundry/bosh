require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/compiled_packages_controller'
require 'tempfile'

module Bosh::Director
  describe Api::Controllers::CompiledPackagesController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::CompiledPackagesController } # "app" is a Rack::Test hook

    before do
      Api::ResourceManager.stub(:new)
    end


    describe 'GET', '/compiled_packages/:release/:release_version/:stemcell_name/:stemcell_version' do
      context 'unauthenticated access' do
        it 'returns 401' do
          get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

          expect(last_response.status).to eq(401)
        end
      end

      context 'accessing with invalid credentials' do
        it 'returns 401' do
          authorize 'invalid-user', 'invalid-password'

          get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

          expect(last_response.status).to eq(401)
        end
      end

      context 'authenticated access' do
        before do
          authorize 'admin', 'admin'

          Models::Stemcell.make(name: 'bosh-stemcell', version: '123')
          release = Models::Release.make(name: 'cf-release')
          Models::ReleaseVersion.make(release: release, version: '456')
        end

        context 'when the specified stemcell and release exist' do
          let(:package_group) { instance_double('Bosh::Director::CompiledPackageGroup') }
          let(:fake_tgz_file) do
            Tempfile.new('fake_tgz').tap do |f|
              f.write('fake tgz content')
              f.close
            end
          end
          let(:exporter) { instance_double('Bosh::Director::CompiledPackagesExporter', tgz_path: fake_tgz_file.path) }

          before do
            CompiledPackageGroup.stub(:new).and_return(package_group)
            CompiledPackagesExporter.stub(:new).and_return(exporter)
          end

          it 'returns a tarball' do
            get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

            expect(last_response.status).to eq(200)
            expect(last_response.content_type).to eq('application/x-compressed')
            expect(last_response.body).to eq('fake tgz content')
          end
        end

        context 'when the stemcell does not exist' do
          it 'returns a 404' do
            get '/stemcells/invalid-stemcell/123/releases/cf-release/456/compiled_packages'

            expect(last_response.status).to eq(404)
          end
        end

        context 'when the release does not exist' do
          it 'returns a 404' do
            get '/stemcells/bosh-stemcell/123/releases/invalid-release/456/compiled_packages'

            expect(last_response.status).to eq(404)
          end
        end
      end
    end
  end
end
