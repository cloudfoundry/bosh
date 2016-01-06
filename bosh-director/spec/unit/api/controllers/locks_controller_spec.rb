require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/locks_controller'

module Bosh::Director
  describe Api::Controllers::LocksController do
    include Rack::Test::Methods

    subject(:app) { described_class.new(config) }
    let(:config) { Config.load_hash(Psych.load(spec_asset('test-director-config.yml'))) }
    before { allow(Api::ResourceManager).to receive(:new) }

    context 'authenticated access' do
      before { authorize 'admin', 'admin' }

      context 'when there are not any locks' do
        let(:locks) { [] }

        it 'should list the current locks' do
          get '/'
          expect(last_response.status).to eq(200)

          body = Yajl::Parser.parse(last_response.body)
          expect(body).to eq([])
        end
      end

      context 'when there are current locks' do
        let(:lock_timeout) { Time.now }

        let(:lock_uid) { SecureRandom.uuid }

        before do
          Models::Lock.make(name: 'lock:deployment:test-deployment', expired_at: lock_timeout)
          Models::Lock.make(name: 'lock:stemcells:test-stemcell', expired_at: lock_timeout)
          Models::Lock.make(name: 'lock:release:test-release', expired_at: lock_timeout)
          Models::Lock.make(name: 'lock:compile:test-package:test-stemcell', expired_at: lock_timeout)
        end

        it 'should list the current locks' do
          get '/'
          expect(last_response.status).to eq(200)

          body = Yajl::Parser.parse(last_response.body)
          timeout_str = lock_timeout.strftime('%s.%6N')
          expect(body).to eq([
            { 'type' => 'deployment', 'resource' => %w(test-deployment), 'timeout' =>timeout_str },
            { 'type' => 'stemcells', 'resource' => %w(test-stemcell), 'timeout' => timeout_str},
            { 'type' => 'release', 'resource' => %w(test-release), 'timeout' => timeout_str },
            { 'type' => 'compile', 'resource' => %w(test-package test-stemcell), 'timeout' => timeout_str },
          ])
        end
      end
    end

    context 'accessing with invalid credentials' do
      before { authorize 'invalid-user', 'invalid-password' }

      it 'returns 401' do
        get '/'
        expect(last_response.status).to eq(401)
      end
    end

    context 'unauthenticated access' do
      it 'returns 401' do
        get '/'
        expect(last_response.status).to eq(401)
      end
    end

    describe 'scope' do
      let(:identity_provider) { Support::TestIdentityProvider.new }
      before { allow(config).to receive(:identity_provider).and_return(identity_provider) }

      it 'accepts read scope for routes allowing read access' do
        authorize 'admin', 'admin'
        get '/'
        expect(identity_provider.scope).to eq(:read)
      end
    end
  end
end
