require 'spec_helper'
require 'fog'
require 'fog/openstack/models/compute/images'
require 'fog/openstack/models/compute/servers'
require 'fog/openstack/models/compute/volumes'
require 'bosh/dev/openstack/micro_bosh_deployment_cleaner'
require 'bosh/dev/openstack/micro_bosh_deployment_manifest'

module Bosh::Dev::Openstack
  describe MicroBoshDeploymentCleaner do
    subject(:cleaner) { described_class.new(manifest) }

    let(:manifest) do
      instance_double(
        'Bosh::Dev::Openstack::MicroBoshDeploymentManifest',
        director_name: 'fake-director-name',
        cpi_options:   'fake-cpi-options',
      )
    end

    describe '#clean' do
      before do
        # disable the 2 minute sleep in clean
        allow(subject).to receive(:sleep) { sleep 1 }
      end

      before { allow(Bosh::OpenStackCloud::Cloud).to receive_messages(new: cloud) }
      let(:cloud) { instance_double('Bosh::OpenStackCloud::Cloud') }

      before { allow(cloud).to receive_messages(openstack: compute) }
      let(:compute) { double('Fog::Compute::OpenStack::Real') }

      before { allow(compute).to receive_messages(servers: servers_collection) }
      let(:servers_collection) { instance_double('Fog::Compute::OpenStack::Servers', all: []) }

      before { allow(compute).to receive_messages(images: image_collection) }
      let(:image_collection) { instance_double('Fog::Compute::OpenStack::Images', all: []) }

      before { allow(compute).to receive_messages(volumes: volume_collection) }
      let(:volume_collection) { instance_double('Fog::Compute::OpenStack::Volumes', all: []) }

      it 'uses openstack cloud with cpi options from the manifest' do
        allow(Bosh::OpenStackCloud::Cloud)
          .to receive(:new)
          .with('fake-cpi-options')
          .and_return(cloud)
        cleaner.clean
      end

      context 'when matching servers are found' do
        before { allow(Bosh::Retryable).to receive_messages(new: retryable) }
        let(:retryable) { instance_double('Bosh::Retryable') }

        it 'terminates servers that have specific microbosh tag name' do
          server_with_non_matching = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name1',
            metadata: make_md('director' => 'non-matching-tag-value'),
          )
          expect(cleaner).to_not receive(:clean_server).with(server_with_non_matching)

          server_with_matching = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name2',
            metadata: make_md('director' => 'fake-director-name'),
          )
          expect(cleaner).to receive(:clean_server).with(server_with_matching)

          microbosh_server = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name3',
            metadata: make_md('Name' => 'fake-director-name'),
          )
          expect(cleaner).to receive(:clean_server).with(microbosh_server)

          allow(retryable).to receive(:retryer).and_yield

          allow(servers_collection).to receive_messages(all: [
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
            volumes: [],
            destroy: nil,
          )

          server2 = instance_double(
            'Fog::Compute::OpenStack::Server',
            name: 'fake-name2',
            metadata: matching_md,
            volumes: [],
            destroy: nil,
          )

          allow(retryable).to receive(:retryer) do |&blk|
            allow(servers_collection).to receive_messages(all: [server1, server2])
            expect(blk.call).to be(false)

            allow(servers_collection).to receive_messages(all: [server2])
            expect(blk.call).to be(false)

            allow(servers_collection).to receive_messages(all: [])
            expect(blk.call).to be(true)
          end

          cleaner.clean
        end

        def make_md(hash)
          instance_double('Fog::Compute::OpenStack::Metadata', to_hash: hash)
        end
      end

      context 'when matching servers are not found' do
        it 'finishes without waiting for anything' do
          allow(servers_collection).to receive_messages(all: [])
          cleaner.clean
        end
      end

      context 'when images exist' do
        let(:image_to_be_deleted_1) do
          instance_double('Fog::Compute::OpenStack::Image', name: 'BOSH-fake-image-1', destroy: nil)
        end

        let(:image_to_be_deleted_2) do
          instance_double('Fog::Compute::OpenStack::Image', name: 'BOSH-fake-image-2', destroy: nil)
        end

        let(:image_to_be_ignored) do
          instance_double('Fog::Compute::OpenStack::Image', name: 'some-other-fake-image', destroy: nil)
        end

        before { allow(image_collection).to receive_messages(all: [image_to_be_deleted_1, image_to_be_deleted_2, image_to_be_ignored]) }

        it 'deletes all images' do
          skip
          cleaner.clean

          expect(image_to_be_deleted_1).to have_received(:destroy)
          expect(image_to_be_deleted_2).to have_received(:destroy)
          expect(image_to_be_ignored).to_not have_received(:destroy)
        end

        it 'logs messages' do
          skip
          cleaner.clean

          expect(logger).to have_received(:info).with('Destroying image BOSH-fake-image-1')
          expect(logger).to have_received(:info).with('Destroying image BOSH-fake-image-2')
          expect(logger).to have_received(:info).with('Ignoring image some-other-fake-image')
        end

      end

      context 'when unattached volumes exist' do
        let(:volume1) do
          instance_double('Fog::Compute::OpenStack::Volume',
                          name: 'fake-volume-1', attachments: [{}], destroy: nil)
        end

        let(:volume2) do
          instance_double('Fog::Compute::OpenStack::Volume',
                          attachments: [
                            { 'device' => '/dev/fake',
                              'serverId' => 'fake-server-id',
                              'id' => 'fake-id',
                              'volumeId' => 'fake-volume-id' }
                          ])
        end

        before { allow(volume_collection).to receive_messages(all: [volume1, volume2]) }

        it 'deletes all unattached volumes' do
          skip
          expect(volume1).to receive(:destroy)
          expect(volume2).to_not receive(:destroy)

          cleaner.clean
        end

        it 'logs messages' do
          skip
          expect(logger).to receive(:info).with('Destroying volume fake-volume-1')

          cleaner.clean
        end
      end
    end

    describe '#clean_server' do
      let(:server) do
        instance_double('Fog::Compute::OpenStack::Server', {
          volumes: [volume1, volume2],
          destroy: nil,
        })
      end

      let(:volume1) do
        instance_double('Fog::Compute::OpenStack::Volume', {
          attachments: [
            { 'serverId' => 'fake-server-id1', 'id' => 'fake-attachment-id1' },
            { 'serverId' => 'fake-server-id2', 'id' => 'fake-attachment-id2' },
          ],
          detach: nil,
        })
      end

      let(:volume2) do
        instance_double('Fog::Compute::OpenStack::Volume', {
          attachments: [
            { 'serverId' => 'fake-server-id1', 'id' => 'fake-attachment-id3' },
            { 'serverId' => 'fake-server-id2', 'id' => 'fake-attachment-id4' },
          ],
          detach: nil,
        })
      end

      before { allow(Bosh::Retryable).to receive_messages(new: retryable) }
      let(:retryable) { instance_double('Bosh::Retryable') }

      it 'detaches and destroys any volumes attached to it and then it destroys the server' do
        allow(retryable).to receive(:retryer).and_yield

        expect(volume1).to receive(:detach).with('fake-server-id1', 'fake-attachment-id1').ordered
        expect(volume1).to receive(:detach).with('fake-server-id2', 'fake-attachment-id2').ordered
        expect(volume1).to receive(:destroy).with(no_args).ordered

        expect(volume2).to receive(:detach).with('fake-server-id1', 'fake-attachment-id3').ordered
        expect(volume2).to receive(:detach).with('fake-server-id2', 'fake-attachment-id4').ordered
        expect(volume2).to receive(:destroy).with(no_args).ordered

        expect(server).to receive(:destroy).with(no_args).ordered

        cleaner.clean_server(server)
      end

      it 'retries to destroy volume until it succeeds' do
        expect(Bosh::Retryable).to receive(:new)
          .with(tries: 10, sleep: 5, on: [Excon::Errors::BadRequest])
          .and_return(retryable)

        blks = []
        allow(retryable).to receive(:retryer) { |&blk| blks << blk }

        cleaner.clean_server(server)

        expect(volume1).to receive(:destroy).with(no_args)
        expect(volume2).to receive(:destroy).with(no_args)
        blks.each(&:call)
      end
    end
  end
end
