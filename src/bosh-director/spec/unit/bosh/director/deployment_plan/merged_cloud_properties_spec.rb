require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe MergedCloudProperties do
    let(:az) { AvailabilityZone.new('az', {}) }
    let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {}}) }
    let(:vm_extensions) { [VmExtension.new({'name' => '', 'cloud_properties' => {}})] }

    subject(:merged_cloud_properties) { MergedCloudProperties.new(az, vm_type, vm_extensions) }

    describe '#cloud_properties' do
      context 'when there is an availability zone' do
        let(:az) { AvailabilityZone.new('az', {'foo' => 'az-foo', 'zone' => 'the-right-one'}) }
        let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {'foo' => 'rp-foo', 'resources' => 'the-good-stuff'}}) }

        it 'merges the vm type into the availability zone cloud properties' do
          expect(subject.get).to eq(
            {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
          )
        end

        context 'when there are vm_extensions' do
          context 'when vm_type and vm_extensions and availability zones have some overlapping cloud properties' do

            let(:vm_extension_1) { VmExtension.new({'name' => 'fake-vm-extension-1', 'cloud_properties' => {'fooz' => 'bar', 'resources' => 'the-new-stuff', 'food' => 'drink'}}) }
            let(:vm_extension_2) { VmExtension.new({'name' => 'fake-vm-extension-2', 'cloud_properties' => {'foo' => 'baaaz', 'food' => 'eat'}}) }
            let(:vm_extensions) { [vm_extension_1, vm_extension_2] }
            let(:az) { AvailabilityZone.new('az', {'foo' => 'az-foo', 'zone' => 'the-right-one', 'other-stuff' => 'who-chares'}) }
            let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {'foo' => 'rp-foo', 'resources' => 'the-good-stuff', 'other-stuff' => 'i-chares'}}) }

            it 'uses the vm_type cloud_properties then the availability zones then rightmost vm_extension for overlapping values' do
              expect(subject.get).to eq({'resources' => 'the-new-stuff', 'foo' => 'baaaz', 'zone' => 'the-right-one', 'food' => 'eat', 'fooz' => 'bar', 'other-stuff' => 'i-chares'})
            end
          end
        end
      end

      context 'when there is no availability zone' do
        let(:az) { nil }
        let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {'foo' => 'rp-foo', 'resources' => 'the-good-stuff'}}) }

        it 'uses just the resource pool cloud properties' do
          expect(subject.get).to eq(
            {'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
          )
        end

        context 'when there are vm_extensions' do
          let(:vm_extension_1) { VmExtension.new({'name' => 'fake-vm-extension-1', 'cloud_properties' => {'foo' => 'bar', 'resources' => 'the-good-stuff'}}) }
          let(:vm_extension_2) { VmExtension.new({'name' => 'fake-vm-extension-2', 'cloud_properties' => {'foo' => 'baaaz'}}) }

          context 'when the same property exists in multiple vm_extensions' do
            let(:vm_extensions) { [vm_extension_1, vm_extension_2] }

            it 'uses the right most vm_extension\'s property value for overlapping values' do
              expect(subject.get).to eq({'resources' => 'the-good-stuff', 'foo' => 'baaaz'})
            end
          end

          context 'when vm_type and vm_extensions have some overlapping cloud properties' do
            let(:vm_extension_1) { VmExtension.new({'name' => 'fake-vm-extension-1', 'cloud_properties' => {'foo' => 'bar'}}) }
            let(:vm_extensions) { [vm_extension_1] }
            let(:vm_type) { VmType.new({'name' => '', 'cloud_properties' => {'foo' => 'rp-foo', 'resources' => 'the-good-stuff'}}) }

            it 'uses the vm_type cloud_properties for overlapping values' do
              expect(subject.get).to eq({'resources' => 'the-good-stuff', 'foo' => 'bar'})
            end
          end
        end
      end

      context 'when there is no vm type' do
        let(:vm_type) { nil }
        it 'does not raise' do
          expect { subject.get }.not_to raise_error
        end
        end

      context 'when there are no vm extensions' do
        let(:vm_extensions) { nil }
        it 'does not raise' do
          expect { subject.get }.not_to raise_error
        end
      end
    end
  end
end
