require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/locks_controller'

module Bosh::Director
  describe Api::Controllers::LocksController do
    include Rack::Test::Methods

    subject(:app) { described_class } # "app" is a Rack::Test hook

    before { Api::ResourceManager.stub(:new) }

    let(:redis) { double('Redis') }

    before do
      BD::Config.stub(:redis).and_return(redis)
    end

    context 'authenticated access' do
      before { authorize 'admin', 'admin' }

      before { redis.should_receive(:keys).with('lock:*').and_return(locks) }

      context 'when there are not any locks' do
        let(:locks) { [] }

        it 'should list the current locks' do
          get '/locks'
          expect(last_response.status).to eq 200

          body = Yajl::Parser.parse(last_response.body)
          expect(body).to be_kind_of(Array)
          expect(body.size).to eql(locks.size)
        end
      end

      context 'when there are current locks' do
        let(:locks) {
          [
            'lock:deployment:test-deployment',
            'lock:stemcells:test-stemcell:1',
            'lock:release:test-release',
            'lock:compile:test-package:test-stemcell'
          ]
        }
        let(:lock_timeout) { Time.now.to_f }
        let(:lock_id) { SecureRandom.uuid }

        before do
          locks.each do |lock|
            redis.should_receive(:get).with(lock).and_return("#{lock_timeout}:#{lock_id}")
          end
        end

        it 'should list the current locks' do
          get '/locks'
          expect(last_response.status).to eq 200

          body = Yajl::Parser.parse(last_response.body)
          expect(body).to be_kind_of(Array)
          expect(body.size).to eql(locks.size)
        end
      end
    end

    context 'accessing with invalid credentials' do
      before { authorize 'invalid-user', 'invalid-password' }

      it 'returns 401' do
        get '/locks'
        expect(last_response.status).to eq(401)
      end
    end

    context 'unauthenticated access' do
      it 'returns 401' do
        get '/locks'
        expect(last_response.status).to eq(401)
      end
    end
  end
end
