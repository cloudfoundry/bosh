require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/locks_controller'

module Bosh::Director
  describe Api::Controllers::LocksController do
    include Rack::Test::Methods

    subject(:app) { described_class.new(config) }
    let(:config) do
      config = Config.load_hash(Psych.load(spec_asset('test-director-config.yml')))
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end
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
        let(:lock_timeout) { Time.now + 1.second }

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

      context 'when there are expired locks' do
        let(:lock_uid) { SecureRandom.uuid }

        before do
          Models::Lock.make(name: 'lock:deployment:test-deployment', expired_at: Time.now - 1.day)
          Models::Lock.make(name: 'lock:stemcells:test-stemcell', expired_at: Time.now - 1.second)
          Models::Lock.make(name: 'lock:release:test-release', expired_at: Time.now - 1.minute)
          Models::Lock.make(name: 'lock:compile:test-package:test-stemcell', expired_at: Time.now - 2.minutes)
        end

        it 'should delete all locks that have expired more than a minute ago from the database' do
          expect(Models::Lock.count).to eq 4

          get '/'

          expect(Models::Lock.map(&:name)).to eq ['lock:stemcells:test-stemcell']
        end

        it 'should list all locks that have not been deleted' do
          get '/'
          expect(last_response.status).to eq(200)

          body = Yajl::Parser.parse(last_response.body)
          expect(body.first['resource']).to eq %w(test-stemcell)
          expect(body.size).to eq 1
        end
      end
    end

    context 'when user has readonly access' do
      before { authorize 'reader', 'reader' }

      context 'when there are not any locks' do
        let(:locks) { [] }

        it 'should list the current locks' do
          get '/'
          expect(last_response.status).to eq(200)

          body = Yajl::Parser.parse(last_response.body)
          expect(body).to eq([])
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
  end
end
