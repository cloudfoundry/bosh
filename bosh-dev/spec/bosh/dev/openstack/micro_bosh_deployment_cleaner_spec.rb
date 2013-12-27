require 'spec_helper'
require 'fog'
require 'fog/openstack/models/compute/servers'
require 'bosh/dev/openstack/micro_bosh_deployment_cleaner'
require 'bosh/dev/openstack/micro_bosh_deployment_manifest'

module Bosh::Dev::Openstack
  describe MicroBoshDeploymentCleaner do
    describe '#clean' do
      subject(:cleaner) { described_class.new(manifest) }

      let(:manifest) do
        instance_double(
          'Bosh::Dev::Openstack::MicroBoshDeploymentManifest',
          director_name: 'fake-director-name',
          cpi_options:   'fake-cpi-options',
        )
      end

      before { Bosh::OpenStackCloud::Cloud.stub(new: cloud) }
      let(:cloud) { instance_double('Bosh::OpenStackCloud::Cloud') }

      before { cloud.stub(openstack: compute) }
      let(:compute) { double('Fog::Compute::OpenStack::Real') }

      before { compute.stub(servers: servers_collection) }
      let(:servers_collection) { instance_double('Fog::Compute::OpenStack::Servers', all: []) }

      before { Logger.stub(new: logger) }
      let(:logger) { instance_double('Logger', info: nil) }

      it 'uses openstack cloud with cpi options from the manifest' do
        Bosh::OpenStackCloud::Cloud
          .should_receive(:new)
          .with('fake-cpi-options')
          .and_return(cloud)
        cleaner.clean
      end

      context 'when matching servers are found' do
        before { Bosh::Retryable.stub(new: retryable) }
        let(:retryable) { instance_double('Bosh::Retryable') }

        it 'terminates servers that have specific microbosh tag name' do
          server_with_non_matching = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name1',
            metadata: make_md('director' => 'non-matching-tag-value'),
          )
          server_with_non_matching.should_not_receive(:destroy)

          server_with_matching = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name2',
            metadata: make_md('director' => 'fake-director-name'),
          )
          server_with_matching.should_receive(:destroy)

          microbosh_server = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name3',
            metadata: make_md('Name' => 'fake-director-name'),
          )
          microbosh_server.should_receive(:destroy)

          retryable.stub(:retryer).and_yield

          servers_collection.stub(all: [
            server_with_non_matching,
            server_with_matching,
            microbosh_server,
          ])

          cleaner.clean
        end

        it 'waits for all the matching servers to be deleted' +
           '(deleted servers are gone from the returned list)' do
          matching_md = make_md('director' => 'fake-director-name')

          server1 = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name1',
            metadata: matching_md,
            destroy: nil,
          )

          server2 = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name2',
            metadata: matching_md,
            destroy: nil,
          )

          retryable.should_receive(:retryer) do |&blk|
            servers_collection.stub(all: [server1, server2])
            blk.call.should be(false)

            servers_collection.stub(all: [server2])
            blk.call.should be(false)

            servers_collection.stub(all: [])
            blk.call.should be(true)
          end

          cleaner.clean
        end

        def make_md(hash)
          instance_double('Fog::Compute::OpenStack::Metadata', to_hash: hash)
        end
      end

      context 'when matching servers are not found' do
        it 'finishes without waiting for anything' do
          servers_collection.stub(all: [])
          cleaner.clean
        end
      end
    end
  end
end
