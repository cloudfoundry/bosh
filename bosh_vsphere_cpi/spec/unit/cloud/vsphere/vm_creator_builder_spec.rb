require 'spec_helper'
# require 'cloud/vsphere/vm_creator_builder'

module VSphereCloud
  describe VmCreatorBuilder do
    describe '#build' do
      let(:memory) { double('memory in mb') }
      let(:disk) { double('disk in mb') }
      let(:cpu) { double('number of cpus') }
      let(:vm_creator) { double('vm creator') }
      let(:resources) { double('resources') }
      let(:client) { double('client') }
      let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
      let(:logger) { double('logger') }
      let(:cpi) { double('cpi') }
      let(:agent_env) { double('agent_env') }
      let(:file_provider) { double('file_provider') }
      let(:disk_provider) { double('disk_provider') }

      let(:cloud_properties) do
        {
          'ram' => memory,
          'disk' => disk,
          'cpu' => cpu,
        }
      end

      before do
        allow(class_double('VSphereCloud::VmCreator').as_stubbed_const).to receive(:new).and_return(vm_creator)
      end

      context 'when nested_hardware_virtualization is not specified' do
        it 'injects the placer, memory size, disk size, number of cpu, vsphere client, logger and the cpi into the VmCreator instance' do
          expect(VSphereCloud::VmCreator).to receive(:new).with(
              memory,
              disk,
              cpu,
              false,
              resources,
              client,
              cloud_searcher,
              logger,
              cpi,
              agent_env,
              file_provider,
              disk_provider
            )

          expect(
            subject.build(resources, cloud_properties, client, cloud_searcher, logger, cpi, agent_env, file_provider, disk_provider)
          ).to eq(vm_creator)
        end
      end

      context 'when nested_hardware_virtualization is customized' do
        before do
          cloud_properties['nested_hardware_virtualization'] = true
        end

        it 'uses the configured value' do
          expect(VSphereCloud::VmCreator).to receive(:new).with(
              memory,
              disk,
              cpu,
              true,
              resources,
              client,
              cloud_searcher,
              logger,
              cpi,
              agent_env,
              file_provider,
              disk_provider
            )

          expect(
            subject.build(resources, cloud_properties, client, cloud_searcher, logger, cpi, agent_env, file_provider, disk_provider)
          ).to eq(vm_creator)
        end
      end
    end
  end
end
