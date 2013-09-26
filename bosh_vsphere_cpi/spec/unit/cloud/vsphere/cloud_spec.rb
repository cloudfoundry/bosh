require 'spec_helper'

describe VSphereCloud::Cloud do
  let(:config) { { fake: 'config' } }
  let(:client) { double('fake client') }

  subject(:vsphere_cloud) { VSphereCloud::Cloud.new(config) }

  before do
    VSphereCloud::Config.should_receive(:configure).with(config)
    VSphereCloud::Config.stub(client: client)
    VSphereCloud::Cloud.any_instance.stub(:at_exit)
  end

  describe 'has_vm?' do
    let(:vm_id) { 'vm_id' }

    context 'the vm is found' do
      it 'returns true' do
        vsphere_cloud.should_receive(:get_vm_by_cid).with(vm_id)
        expect(vsphere_cloud.has_vm?(vm_id)).to be_true
      end
    end

    context 'the vm is not found' do
      it 'returns false' do
        vsphere_cloud.should_receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
        expect(vsphere_cloud.has_vm?(vm_id)).to be_false
      end
    end
  end

  describe 'snapshot_disk' do
    it 'raises not implemented exception when called' do
      expect { vsphere_cloud.snapshot_disk('123') }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  describe '#replicate_stemcell' do
    let(:stemcell_vm) { double('fake local stemcell') }
    let(:stemcell_id) { 'fake_stemcell_id' }

    let(:datacenter) do
      datacenter = double('fake datacenter', name: 'fake_datacenter')
      datacenter.stub_chain(:template_folder, :name).and_return('fake_template_folder')
      datacenter
    end
    let(:cluster) { double('fake cluster', datacenter: datacenter) }
    let(:datastore) { double('fake datastore') }

    context 'when stemcell vm is not found at the expected location' do
      it 'raises an error' do
        client.stub(find_by_inventory_path: nil)

        expect {
          vsphere_cloud.replicate_stemcell(cluster, datastore, 'fake_stemcell_id')
        }.to raise_error(/Could not find stemcell/)
      end
    end

    context 'when stemcell vm resides on a different datastore' do
      before do
        datastore.stub_chain(:mob, :__mo_id__).and_return('fake_datastore_managed_object_id')
        client.stub(:find_by_inventory_path).with(
          [
            cluster.datacenter.name,
            "vm",
            cluster.datacenter.template_folder.name,
            stemcell_id,
          ]
        ).and_return(stemcell_vm)

        client.stub(:get_property).with(stemcell_vm, anything, 'datastore', anything).and_return('fake_stemcell_datastore')
      end

      it 'searches for stemcell on all cluster datastores' do
        client.should_receive(:find_by_inventory_path).with(
          [
            cluster.datacenter.name,
            "vm",
            cluster.datacenter.template_folder.name,
            "#{stemcell_id} %2f #{datastore.mob.__mo_id__}",
          ]
        ).and_return(double('fake stemcell vm'))

        vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id)
      end

      context 'when the stemcell replica is not found in the datacenter' do
        let(:replicated_stemcell) { double('fake_replicated_stemcell') }
        let(:fake_task) { 'fake_task' }

        it 'replicates the stemcell' do
          client.stub(:find_by_inventory_path).with(
            [
              cluster.datacenter.name,
              "vm",
              cluster.datacenter.template_folder.name,
              "#{stemcell_id} %2f #{datastore.mob.__mo_id__}",
            ]
          )

          datacenter.stub_chain(:template_folder, :mob).and_return('fake_template_folder_mob')
          cluster.stub_chain(:resource_pool, :mob).and_return('fake_resource_pool_mob')
          stemcell_vm.stub(:clone).with(any_args).and_return(fake_task)
          client.stub(:wait_for_task).with(fake_task).and_return(replicated_stemcell)
          replicated_stemcell.stub(:create_snapshot).with(any_args).and_return(fake_task)

          vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id).should eq(replicated_stemcell)
        end
      end
    end

    context 'when stemcell resides on the given datastore' do

      it 'returns the found replica' do
        client.stub(:find_by_inventory_path).with(any_args).and_return(stemcell_vm)
        client.stub(:get_property).with(any_args).and_return(datastore)
        datastore.stub(:mob).and_return(datastore)

        vsphere_cloud.replicate_stemcell(cluster, datastore, stemcell_id).should eq(stemcell_vm)

      end
    end
  end
end
