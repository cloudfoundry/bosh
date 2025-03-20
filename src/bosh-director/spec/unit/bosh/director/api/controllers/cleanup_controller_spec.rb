require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::CleanupController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.director_config_hash) }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      context 'when request body asks to delete orphaned disks' do
        it 'cleans up all orphaned disks' do
          post('/', JSON.generate('config' => { 'remove_all' => true }), 'CONTENT_TYPE' => 'application/json')

          expect_redirect_to_queued_task(last_response)
        end
      end

      context 'when asking to see artfacts that will be cleaned' do
        before :each do
          FactoryBot.create(:models_orphan_disk, disk_cid: 'fake-cid-2')
        end
        context 'without specifying remove all' do
          it 'returns json hiding some elements' do
            get('/dryrun?remove_all=false')

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq(
              'compiled_packages' => [],
              'dns_blobs' => [],
              'exported_releases' => [],
              'orphaned_disks' => [],
              'orphaned_vms' => [],
              'releases' => [],
              'stemcells' => [],
            )
          end
        end
        context 'with specifying remove all' do
          it 'returns all items that can be deleted' do
            get('/dryrun?remove_all=true')

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to match(
              'compiled_packages' => [],
              'dns_blobs' => [],
              'exported_releases' => [],
              'orphaned_disks' => [{
                'disk_cid' => 'fake-cid-2',
                'az' => anything,
                'size' => anything,
                'orphaned_at' => String,
                'deployment_name' => String,
                'instance_name' => String,
                'cloud_properties' => {},
              }],
              'orphaned_vms' => [],
              'releases' => [],
              'stemcells' => [],
            )
          end
        end
      end
    end
  end
end
