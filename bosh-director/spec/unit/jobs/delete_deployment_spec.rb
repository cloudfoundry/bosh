require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteDeployment do
    subject(:job) { described_class.new('test_deployment', job_options) }
    let(:job_options) { {} }

    before { allow(Config).to receive(:cloud).and_return(cloud) }
    let(:cloud) { instance_double('Bosh::Cloud') }

    before { App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    describe 'Resque job class expectations' do
      let(:job_type) { :delete_deployment }
      it_behaves_like 'a Resque job'
    end

    describe 'delete_instance' do
      let(:instance) { Models::Instance.make(vm: nil) }

      it "should delete the disk if it's not attached to the VM" do
        Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
        cloud.should_receive(:delete_disk).with('disk-cid')
        job.delete_instance(instance)
        Models::Instance[instance.id].should be_nil
      end

      it 'should detach and delete disk if there is a disk' do
        agent = double('agent')

        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-1')

        instance = Models::Instance.make(vm: vm)

        Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)

        agent.should_receive(:stop)
        agent.should_receive(:unmount_disk).with('disk-cid')

        cloud.should_receive(:detach_disk).with('vm-cid', 'disk-cid')
        cloud.should_receive(:delete_disk).with('disk-cid')

        job.should_receive(:delete_vm).with(vm)

        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should only delete the VM if there is no disk' do
        agent = double('agent')

        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-1')
        instance = Models::Instance.make(vm: vm)

        agent.should_receive(:stop)

        job.should_receive(:delete_vm).with(vm)

        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'deletes the model if there is no VM' do
        instance.update(vm: nil)
        job.delete_instance(instance)
        Models::Instance[instance.id].should be_nil
      end

      it 'should ignore cpi errors if forced' do
        vm = Models::Vm.make(cid: 'vm-cid')
        instance.update(vm: vm)

        Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)

        cloud.should_receive(:detach_disk).with('vm-cid', 'disk-cid').and_raise('ERROR')
        cloud.should_receive(:delete_disk).with('disk-cid').and_raise('ERROR')

        job = Jobs::DeleteDeployment.new('test_deployment', 'force' => true)
        job.should_receive(:delete_vm).with(vm)
        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should delete the snapshots' do
        disk = Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
        Models::Snapshot.make(snapshot_cid: 'snap1a', persistent_disk_id: disk.id)

        cloud.should_receive(:delete_snapshot).with('snap1a')
        cloud.should_receive(:delete_disk).with('disk-cid')

        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      it 'should not delete the snapshots if keep_snapshots is set' do
        disk = Models::PersistentDisk.make(disk_cid: 'disk-cid', instance_id: instance.id)
        Models::Snapshot.make(snapshot_cid: 'snap1a', persistent_disk_id: disk.id)

        cloud.should_not_receive(:delete_snapshot)
        cloud.should_receive(:delete_disk).with('disk-cid')

        job = Jobs::DeleteDeployment.new('test_deployment', 'keep_snapshots' => true)
        job.delete_instance(instance)

        Models::Instance[instance.id].should be_nil
      end

      describe 'deleting job templates' do
        let(:instance) { Models::Instance.make(vm: nil) }

        before { allow(RenderedJobTemplatesCleaner).to receive(:new).with(instance, blobstore).and_return(job_templates_cleaner) }
        let(:job_templates_cleaner) { instance_double('Bosh::Director::RenderedJobTemplatesCleaner') }

        it 'deletes rendered job templates before deleting an instance' do
          expect(job_templates_cleaner).to receive(:clean_all).with(no_args).ordered
          expect(instance).to receive(:destroy).ordered
          job.delete_instance(instance)
        end

        context 'when deletion fails with some error' do
          before { allow(job_templates_cleaner).to receive(:clean_all).and_raise(error) }
          let(:error) { RuntimeError.new('error') }

          context 'when force option is not specified' do
            it 'does not ignore errors and re-raises them' do
              expect { job.delete_instance(instance) }.to raise_error(error)
            end
          end

          context 'when force option is specified' do
            it 'ignores errors raised when deleting rendered job templates' do
              job_options.merge!('force' => true)
              expect { job.delete_instance(instance) }.to_not raise_error
            end
          end
        end
      end
    end

    describe '#delete_vm' do
      context 'when cid of the vm is not specified' do
        let!(:vm) { Models::Vm.make(cid: nil) }

        it 'only deletes vm from the database' do
          expect {
            job.delete_vm(vm)
          }.to change { Models::Vm[vm.id] }.from(vm).to(nil)
        end
      end

      context 'when cid of the vm is specified' do
        let!(:vm) { Models::Vm.make(cid: 'fake-vm-cid') }

        it 'deletes VM from the cloud and then deletes vm from the database' do
          expect(cloud).to receive(:delete_vm).with('fake-vm-cid').ordered
          expect(vm).to receive(:destroy).with(no_args).ordered
          job.delete_vm(vm)
        end

        context 'when deletion vm from the cloud fails with some error' do
          before { allow(cloud).to receive(:delete_vm).and_raise(error) }
          let(:error) { RuntimeError.new('error') }

          context 'when force option is not specified' do
            it 'does not ignore errors and re-raises them' do
              expect { job.delete_vm(vm) }.to raise_error(error)
            end
          end

          context 'when force option is specified' do
            it 'ignores errors raised' do
              job_options.merge!('force' => true)
              expect { job.delete_vm(vm) }.to_not raise_error
            end
          end
        end
      end
    end

    describe 'perform' do
      it 'deletes all the associated instances, VMs, disks and problems' do
        agent = double('agent')

        AgentClient.stub(:with_defaults).with('agent-1').and_return(agent)

        stemcell = Models::Stemcell.make
        deployment = Models::Deployment.make(name: 'test_deployment')

        deployment.stemcells << stemcell

        vm = Models::Vm.make(deployment: deployment, agent_id: 'agent-1')

        instance = Models::Instance.make(deployment: deployment, vm: vm)
        problem = Models::DeploymentProblem.make(deployment: deployment)
        disk = Models::PersistentDisk.make(instance: instance, disk_cid: 'disk-cid')

        cloud.stub(:delete_vm)
        cloud.stub(:delete_disk)
        cloud.stub(:detach_disk)

        agent.should_receive(:stop)
        agent.should_receive(:unmount_disk).with('disk-cid')

        job.should_receive(:with_deployment_lock).with('test_deployment').and_yield
        job.perform

        Models::Deployment[deployment.id].should be_nil

        stemcell.refresh
        stemcell.deployments.should be_empty

        Models::Vm[vm.id].should be_nil
        Models::Instance[instance.id].should be_nil
        Models::DeploymentProblem[problem.id].should be_nil
        Models::PersistentDisk[disk.id].should be_nil
      end

      it 'should fail if the deployment is not found' do
        lambda { job.perform }.should raise_exception DeploymentNotFound
      end
    end
  end
end
