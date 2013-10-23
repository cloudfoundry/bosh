require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/compiled_packages_controller'

module Bosh::Director::Api
  describe Controllers::CompiledPackagesController do
    include Rack::Test::Methods

    subject(:app) { Controllers::CompiledPackagesController } # "app" is a Rack::Test hook

    before do
      Controllers::CompiledPackagesController.enable(:raise_errors)
      Controllers::CompiledPackagesController.disable(:show_exceptions)

      ResourceManager.stub(:new)
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
        before { authorize 'admin', 'admin' }

        it 'returns a tarball' do
          get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to eq('application/x-compressed')
        end
      end
    end
  end
end
