require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::OrphanedVmsController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

      before do
        App.new(config)
      end

      context '/orphaned_vms' do
        let!(:orphaned_vm1) { FactoryBot.create(:models_orphaned_vm) }
        let!(:orphaned_vm2) { FactoryBot.create(:models_orphaned_vm) }

        before do
          basic_authorize 'admin', 'admin'

          FactoryBot.create(:models_ip_address, instance: nil, orphaned_vm: orphaned_vm1)
          FactoryBot.create(:models_ip_address, instance: nil, orphaned_vm: orphaned_vm1)
        end

        it 'returns a list of orphaned vms' do
          get '/'

          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)

          expect(body.size).to eq(2)

          first = body.find { |vm| vm['cid'] == orphaned_vm1.cid }
          last  = body.find { |vm| vm['cid'] == orphaned_vm2.cid }

          expect(first['cid']).to eq(orphaned_vm1.cid)
          expect(first['deployment_name']).to eq(orphaned_vm1.deployment_name)
          expect(first['instance_name']).to eq(orphaned_vm1.instance_name)
          expect(first['az']).to eq(orphaned_vm1.availability_zone)
          expect(first['ip_addresses']).to contain_exactly(/\d+\.\d+\.\d+\.\d+/, /\d+\.\d+\.\d+\.\d+/)
          expect(first['ip_addresses']).to contain_exactly(*orphaned_vm1.ip_addresses.map(&:formatted_ip))
          expect(first['orphaned_at']).to eq(orphaned_vm1.orphaned_at.to_s)

          expect(last['cid']).to eq(orphaned_vm2.cid)
          expect(last['deployment_name']).to eq(orphaned_vm2.deployment_name)
          expect(last['instance_name']).to eq(orphaned_vm2.instance_name)
          expect(last['az']).to eq(orphaned_vm2.availability_zone)
          expect(last['ip_addresses']).to eq([])
          expect(last['orphaned_at']).to eq(orphaned_vm2.orphaned_at.to_s)
        end
      end
    end
  end
end
