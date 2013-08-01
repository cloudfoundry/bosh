require 'spec_helper'
require 'bosh/dev/infrastructure'

module Bosh::Dev
  describe Infrastructure do
    describe '.for' do
      it 'returns the correct infrastrcture' do
        expect(Infrastructure.for('openstack')).to be_an(Infrastructure::OpenStack)
        expect(Infrastructure.for('aws')).to be_an(Infrastructure::Aws)
        expect(Infrastructure.for('vsphere')).to be_a(Infrastructure::Vsphere)
      end

      it 'raises for unknown instructures' do
        expect { Infrastructure.for('BAD_INFRASTRUCTURE') }.to raise_error(ArgumentError, /invalid infrastructure: BAD_INFRASTRUCTURE/)
      end
    end
  end

  describe Infrastructure::Aws do
    its(:name) { should eq('aws') }
    it { should be_light }
    its(:hypervisor) { should be_nil }

    describe '#run_system_micro_tests' do
      let(:fake_rake_task) { double('a Rake Task') }

      it 'invokes the correct Rake::Task' do
        fake_rake_task.should_receive(:invoke)
        Rake::Task.should_receive(:[]).with('spec:system:aws:micro').and_return(fake_rake_task)

        subject.run_system_micro_tests
      end
    end
  end

  describe Infrastructure::OpenStack do
    its(:name) { should eq('openstack') }
    it { should_not be_light }
    its(:hypervisor) { should eq('kvm') }

    describe '#run_system_micro_tests' do
      let(:fake_rake_task) { double('a Rake Task') }

      it 'invokes the correct Rake::Task' do
        fake_rake_task.should_receive(:invoke)
        Rake::Task.should_receive(:[]).with('spec:system:openstack:micro').and_return(fake_rake_task)

        subject.run_system_micro_tests
      end
    end
  end

  describe Infrastructure::Vsphere do
    its(:name) { should eq('vsphere') }
    it { should_not be_light }
    its(:hypervisor) { should be_nil }

    describe '#run_system_micro_tests' do
      let(:fake_rake_task) { double('a Rake Task') }

      it 'invokes the correct Rake::Task' do
        fake_rake_task.should_receive(:invoke)
        Rake::Task.should_receive(:[]).with('spec:system:vsphere:micro').and_return(fake_rake_task)

        subject.run_system_micro_tests
      end
    end
  end
end
