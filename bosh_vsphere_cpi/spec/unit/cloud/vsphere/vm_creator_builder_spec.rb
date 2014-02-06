require 'cloud/vsphere/vm_creator_builder'

module VSphereCloud
  describe VmCreatorBuilder do
    describe '#build' do
      it 'injects the placer, memory size, disk size, number of cpu, vsphere client, logger and the cpi into the VmCreator instance' do
        resources = double('resources')
        client = double('client')
        logger = double('logger')
        cpi = double('cpi')
        vm_creator = double('vm creator')
        expect(
          class_double('VSphereCloud::VmCreator').as_stubbed_const
        ).to receive(:new).with(resources, client, logger, cpi).and_return(vm_creator)

        expect(subject.build(resources, client, logger, cpi)).to eq(vm_creator)
      end
    end
  end
end
