require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe VmRequirementsCache do
    subject {VmRequirementsCache.new(cloud_factory, logger)}

    let(:cloud_factory) {Bosh::Director::CloudFactory.create_with_latest_configs}
    let(:fake_cpi1) {instance_double(Bosh::Clouds::ExternalCpi)}
    let(:fake_cpi2) {instance_double(Bosh::Clouds::ExternalCpi)}

    let(:cloud_config) {Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs_and_cpis}

    let(:vm_requirements) {{
        'cpu' => 4,
        'ram' => 16384,
        'ephemeral_disk_size' => 100
    }}

    let(:cpi_config) { Bosh::Director::Models::CpiConfig.make }

    let(:vm_cloud_properties1) {
      {vm_cloud_properties: 1}
    }

    let(:vm_cloud_properties2) {
      {vm_cloud_properties: 2}
    }

    before do
      Bosh::Director::Models::CloudConfig.make(raw_manifest: cloud_config)

      allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(
        '/var/vcap/jobs/cpi-type_cpi/bin/cpi',
        Bosh::Director::Config.uuid,
        YAML.load(cpi_config.properties)['cpis'][0]['properties']
      ).and_return(fake_cpi1)

      allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(
        '/var/vcap/jobs/cpi-type2_cpi/bin/cpi',
        Bosh::Director::Config.uuid,
        YAML.load(cpi_config.properties)['cpis'][1]['properties']
      ).and_return(fake_cpi2)

      allow(fake_cpi1).to receive(:calculate_vm_cloud_properties).with(vm_requirements).and_return(vm_cloud_properties1)
      allow(fake_cpi2).to receive(:calculate_vm_cloud_properties).with(vm_requirements).and_return(vm_cloud_properties2)
    end

    it 'returns cloud_properties from the CPI' do
      result = subject.get_vm_cloud_properties('cpi-name1', vm_requirements)

      expect(result).to eq(vm_cloud_properties1)
    end

    it 'logs the vm cloud properties returned by the CPI' do
      expect(logger).to receive(:info).with("CPI cpi-name1 calculated vm cloud properties '#{vm_cloud_properties1}' for vm requirements '#{vm_requirements}'")

      subject.get_vm_cloud_properties('cpi-name1', vm_requirements)
    end

    context 'when two azs use two cpis' do
      context 'when the vm_requirements are the same' do
        it 'multiple calls to the same az return the cached value' do
          first_result = subject.get_vm_cloud_properties('cpi-name1', vm_requirements)
          second_result = subject.get_vm_cloud_properties('cpi-name1', vm_requirements)

          expect(first_result).to eq(second_result)
          expect(fake_cpi1).to have_received(:calculate_vm_cloud_properties).once
        end

        it 'multiple calls to the different azs call the cpi' do
          first_result = subject.get_vm_cloud_properties('cpi-name1', vm_requirements)
          second_result = subject.get_vm_cloud_properties('cpi-name2', vm_requirements)

          expect(first_result).to_not eq(second_result)
          expect(fake_cpi1).to have_received(:calculate_vm_cloud_properties).once
          expect(fake_cpi2).to have_received(:calculate_vm_cloud_properties).once
        end
      end
    end

    context 'when the vm_requirements are NOT the same' do
      let(:vm_requirements2) {{
        'cpu' => 2,
        'ram' => 2048,
        'ephemeral_disk_size' => 100
      }}

      it 'multiple calls to the same az call the cpi' do
        allow(fake_cpi1).to receive(:calculate_vm_cloud_properties).with(vm_requirements2).and_return(vm_cloud_properties2)

        first_result = subject.get_vm_cloud_properties('cpi-name1', vm_requirements)
        second_result = subject.get_vm_cloud_properties('cpi-name1', vm_requirements2)

        expect(first_result).to_not eq(second_result)
        expect(fake_cpi1).to have_received(:calculate_vm_cloud_properties).twice
      end
    end

  end
end
