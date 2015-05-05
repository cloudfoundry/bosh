require 'spec_helper'
require 'timecop'

describe VSphereCloud::Resources::VM do
  subject(:vm) { described_class.new('vm-cid', vm_mob, client, logger) }
  let(:vm_mob) { instance_double('VimSdk::Vim::VirtualMachine') }
  let(:client) { instance_double('VSphereCloud::Client', cloud_searcher: cloud_searcher) }
  let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
  let(:logger) { double(:logger, debug: nil, info: nil) }

  let(:powered_off_state) { VimSdk::Vim::VirtualMachine::PowerState::POWERED_OFF }
  let(:powered_on_state) { VimSdk::Vim::VirtualMachine::PowerState::POWERED_ON }

  before do
    allow(cloud_searcher).to receive(:get_properties).with(
      vm_mob,
      VimSdk::Vim::VirtualMachine,
      ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name', 'runtime', 'resourcePool'],
      ensure: ['config.hardware.device', 'runtime']
    ).and_return(vm_properties)
  end

  let(:vm_properties) { {'runtime' => double(:runtime, host: 'vm-host')} }

  describe 'accessible_datastores' do
    it 'returns accessible_datastores' do
      datastore_mob = instance_double('VimSdk::Vim::Datastore')
      host_properties = {'datastore' => [datastore_mob]}
      allow(cloud_searcher).to receive(:get_properties).with(
        'vm-host',
        VimSdk::Vim::HostSystem,
        ['datastore', 'parent'],
        ensure_all: true,
      ).and_return(host_properties)
      allow(cloud_searcher).to receive(:get_properties).with(
        datastore_mob,
        VimSdk::Vim::Datastore,
        'info',
        ensure_all: true,
      ).and_return({'info' => double(:info, name: 'datastore-name')})

      expect(vm.accessible_datastores).to eq(['datastore-name'])
    end
  end

  describe 'fix_device_unit_numbers' do
    let(:vm_properties) { { 'config.hardware.device' => vm_devices } }
    let(:vm_devices) do
      vm_devices = []
      4.times do |i|
        vm_devices << double(:device, controller_key: 7, unit_number: i)
      end
      vm_devices
    end

    let(:device_changes) { [double(:device_change, device: device)] }
    let(:device) { VimSdk::Vim::Vm::Device::VirtualDisk.new(controller_key: 7) }

    it 'sets device unit number to available unit number' do
      vm.fix_device_unit_numbers(device_changes)
      expect(device.unit_number).to eq(4)
    end

    context 'when devices use all available unit numbers' do
      let(:vm_devices) do
        vm_devices = []
        16.times do |i|
          vm_devices << double(:device, controller_key: 7, unit_number: i)
        end
        vm_devices
      end

      it 'raises an error' do
        expect {
          vm.fix_device_unit_numbers(device_changes)
        }.to raise_error /No available unit numbers/
      end
    end
  end

  describe 'shutdown' do
    it 'sends shutdown signal' do
      allow(cloud_searcher).to receive(:get_property).
        with(vm_mob, VimSdk::Vim::VirtualMachine, 'runtime.powerState').
        and_return(powered_off_state)

      expect(vm_mob).to receive(:shutdown_guest)
      vm.shutdown
    end

    it 'waits until vm is powered off' do
      expect(cloud_searcher).to receive(:get_property).
        with(vm_mob, VimSdk::Vim::VirtualMachine, 'runtime.powerState').
        and_return(powered_on_state, powered_on_state, powered_off_state).
        exactly(3).times
      expect(vm).to receive(:sleep).with(1.0).exactly(2).times

      expect(vm_mob).to receive(:shutdown_guest)
      vm.shutdown
    end

    context 'when waiting for shutdown exceeds 60 seconds' do
      it 'powers off vm' do
        started_time = Time.now
        passed_time = started_time + 61
        Timecop.freeze(started_time)

        expect(cloud_searcher).to receive(:get_property).with(
          vm_mob,
          VimSdk::Vim::VirtualMachine,
          'runtime.powerState'
        ) do
          Timecop.freeze(passed_time)
        end.and_return(powered_on_state)

        expect(vm_mob).to receive(:shutdown_guest)
        expect(client).to receive(:power_off_vm).with(vm_mob)
        vm.shutdown
      end
    end

    context 'when shutting down vm raises an error' do
      before do
        allow(vm_mob).to receive(:shutdown_guest).and_raise RuntimeError
      end

      it 'ignores the error and waits until vm is powered off' do
        expect(cloud_searcher).to receive(:get_property).
          with(vm_mob, VimSdk::Vim::VirtualMachine, 'runtime.powerState').
          and_return(powered_off_state)

        expect {
          vm.shutdown
        }.to_not raise_error
      end
    end
  end

  describe 'power_off' do
    before do
      allow(cloud_searcher).to receive(:get_property).with(
        vm_mob,
        VimSdk::Vim::VirtualMachine,
        ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name', 'runtime', 'resourcePool'],
        ensure: ['config.hardware.device', 'runtime']
      ).and_return({'runtime.question' => nil})
    end

    context 'when vsphere asks question' do
      before do
        choice_info = {2 => double(:second_choice, label: 'YES', key: 'yes')}
        choice = double(:choices, choice_info: choice_info, default_index: 2)
        question = double(:question, choice: choice, id: 'question-id', text: 'question?')
        allow(cloud_searcher).to receive(:get_properties).with(
          vm_mob,
          VimSdk::Vim::VirtualMachine,
          ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name', 'runtime', 'resourcePool'],
          ensure: ['config.hardware.device', 'runtime']
        ).and_return({'runtime.question' => question})
        allow(cloud_searcher).to receive(:get_property).with(
          vm_mob,
          VimSdk::Vim::VirtualMachine,
          'runtime.powerState',
        ).and_return(powered_off_state)
      end

      it 'answers the question' do
        expect(client).to receive(:answer_vm).with(vm_mob, 'question-id', 'yes')
        vm.power_off
      end
    end

    context 'when current state is not powered off' do
      it 'sends power off' do
        expect(client).to receive(:power_off_vm).with(vm_mob)
        vm.power_off
      end
    end

    context 'when current state is powered off' do
      before do
        allow(cloud_searcher).to receive(:get_properties).with(
          vm_mob,
          VimSdk::Vim::VirtualMachine,
          ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name', 'runtime', 'resourcePool'],
          ensure: ['config.hardware.device', 'runtime']
        ).and_return({'runtime.powerState' => powered_off_state})
      end

      it 'does not send power off' do
        expect(client).to_not receive(:power_off_vm).with(vm_mob)
        vm.power_off
      end
    end
  end
end
