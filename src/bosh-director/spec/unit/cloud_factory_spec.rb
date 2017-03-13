require 'spec_helper'

module Bosh::Director
  describe CloudFactory do
    subject(:cloud_factory) { described_class.new(cloud_planner, parsed_cpi_config) }
    let(:default_cloud) { Config.cloud }
    let(:cloud_planner) { instance_double(DeploymentPlan::CloudPlanner) }
    let(:parsed_cpi_config) { CpiConfig::ParsedCpiConfig.new(cpis) }
    let(:cpis) {[]}
    let(:logger) { double(:logger, debug: nil) }
    let(:all_cpis) do
      clouds = [{name: '', cpi: default_cloud}]
      cpis.each do |cpi|
        clouds << {name: cpi.name, cpi: Bosh::Clouds::ExternalCpi.new(cpi.exec_path, Config.uuid, cpi.properties)}
      end

      CloudCollection.new(clouds, logger)
    end

    context 'factory methods' do
      let(:cpi_config) { instance_double(Models::CpiConfig) }
      let(:cloud_config) { instance_double(Models::CloudConfig) }
      let(:deployment) { instance_double(Models::Deployment) }
      let(:cpi_manifest_parser) { instance_double(CpiConfig::CpiManifestParser) }
      let(:cloud_manifest_parser) { instance_double(DeploymentPlan::CloudManifestParser) }
      let(:planner) { instance_double(DeploymentPlan::CloudPlanner) }

      before {
        allow(deployment).to receive(:cloud_config).and_return(cloud_config)
        allow(cloud_config).to receive(:manifest).and_return({})
        allow(CpiConfig::CpiManifestParser).to receive(:new).and_return(cpi_manifest_parser)
        allow(cpi_manifest_parser).to receive(:parse).and_return(parsed_cpi_config)
        allow(cpi_config).to receive(:manifest).and_return({})
        allow(DeploymentPlan::CloudManifestParser).to receive(:new).and_return(cloud_manifest_parser)
        allow(cloud_manifest_parser).to receive(:parse).and_return(planner)
      }

      it 'constructs a cloud factory with all its dependencies from a deployment' do
        expect(described_class).to receive(:new).with(planner, parsed_cpi_config)
        described_class.create_from_deployment(deployment, cpi_config)
      end

      it 'constructs a cloud factory without planner if no deployment is given' do
        expect(described_class).to receive(:new).with(nil, parsed_cpi_config)
        deployment = nil
        described_class.create_from_deployment(deployment, cpi_config)
      end

      it 'constructs a cloud factory without planner if no cloud config is used' do
        expect(described_class).to receive(:new).with(nil, parsed_cpi_config)
        expect(deployment).to receive(:cloud_config).and_return(nil)
        described_class.create_from_deployment(deployment, cpi_config)
      end

      it 'constructs a cloud factory without parsed cpis if no cpi config is used' do
          expect(described_class).to receive(:new).with(planner, nil)
          described_class.create_from_deployment(deployment, nil)
      end
    end

    shared_examples_for 'lookup for clouds' do
      it 'returns the default cloud from director config when asking for the cloud of a nil AZ' do
        cloud = cloud_factory.for_availability_zone!(nil)
        expect(cloud).to eq(default_cloud)
      end

      it 'returns the default cloud when asking for the cloud of a non-existing AZ' do
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(nil)

        expect {
          cloud_factory.for_availability_zone!('some-az')
        }.to raise_error /AZ some-az not found in cloud config/
      end

      it 'returns the default cloud from director config when asking for the cloud of an existing AZ without cpi' do
        az = DeploymentPlan::AvailabilityZone.new('some-az', {}, nil)
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)
        cloud = cloud_factory.for_availability_zone!('some-az')
        expect(cloud).to eq(default_cloud)
      end

      it 'raises an error if an AZ references a CPI that does not exist anymore' do
        az = DeploymentPlan::AvailabilityZone.new('some-az', {}, 'not-existing-cpi')
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)
        expect {
          cloud_factory.for_availability_zone!('some-az')
        }.to raise_error /CPI was defined for AZ some-az but not found in cpi-config/
      end

      context 'without planner' do
        let(:cloud_planner) { nil }

        it 'returns the default cloud from director config when asking for the cloud of a nil AZ' do
          cloud = cloud_factory.for_availability_zone!(nil)
          expect(cloud).to eq(default_cloud)
        end

        it 'raises an error if lookup of an AZ is needed' do
          expect {
            cloud_factory.for_availability_zone!('some-az')
          }.to raise_error /Deployment plan must be given to lookup cpis from AZ/
        end
      end

      it 'returns nil if asking for a given cpi' do
        expect(cloud_factory.for_cpi('doesntmatter')).to be_nil
      end

      it 'returns nil if asking for a nil cpi' do
        expect(cloud_factory.for_cpi(nil)).to be_nil
      end

      it 'raises an error if lookup_cpi_for_az is called for a nil az' do
        expect {
          cloud_factory.lookup_cpi_for_az(nil)
        }.to raise_error /AZ name must not be nil/
      end
    end

    shared_examples_for 'lookup for clouds with fallback' do
      it 'returns all configured cpis when asking for the cloud of a nil AZ' do
        cloud = cloud_factory.for_availability_zone(nil)
        expect(cloud).to eq(all_cpis)
      end

      it 'returns all configured cpis when asking for the cloud of a non-existing AZ' do
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(nil)

        cloud = cloud_factory.for_availability_zone('some-az')
        expect(cloud).to eq(all_cpis)
      end

      it 'returns all configured cpis when asking for the cloud of an existing AZ without cpi' do
        az = DeploymentPlan::AvailabilityZone.new('some-az', {}, nil)
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)
        cloud = cloud_factory.for_availability_zone('some-az')
        expect(cloud).to eq(all_cpis)
      end

      it 'returns all configured cpis when an AZ references a CPI that does not exist anymore' do
        az = DeploymentPlan::AvailabilityZone.new('some-az', {}, 'not-existing-cpi')
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)

        cloud = cloud_factory.for_availability_zone('some-az')
        expect(cloud).to eq(all_cpis)
      end

      context 'without planner' do
        let(:cloud_planner) { nil }

        it 'returns all configured cpis when asking for the cloud of a nil AZ' do
          cloud = cloud_factory.for_availability_zone(nil)
          expect(cloud).to eq(all_cpis)
        end

        it 'raises an error if lookup of an AZ is needed' do
          expect {
            cloud_factory.for_availability_zone('some-az')
          }.to raise_error /Deployment plan must be given to lookup cpis from AZ/
        end
      end
    end

    context 'when not using cpi config' do
      let(:parsed_cpi_config) { nil }
      before {
        expect(cloud_factory.uses_cpi_config?).to be_falsey
      }

      it 'returns the default cloud from director config when asking for all configured clouds' do
        all_clouds = cloud_factory.all_configured_clouds
        expect(all_clouds.count).to eq(1)
        expect(all_clouds.first[:name]).to eq('')
        expect(all_clouds.first[:cpi]).to eq(default_cloud)
      end

      it_behaves_like 'lookup for clouds'
      it_behaves_like 'lookup for clouds with fallback'
    end

    context 'when using cpi config' do
      let(:cpis) {
        [
            CpiConfig::Cpi.new('name1', 'type1', nil, {'prop1' => 'val1'}),
            CpiConfig::Cpi.new('name2', 'type2', nil, {'prop2' => 'val2'}),
            CpiConfig::Cpi.new('name3', 'type3', nil, {'prop3' => 'val3'}),
        ]
      }

      let(:clouds) {
        [
            instance_double(Bosh::Cloud),
            instance_double(Bosh::Cloud),
            instance_double(Bosh::Cloud)
        ]
      }

      before {
        expect(cloud_factory.uses_cpi_config?).to be_truthy
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path, Config.uuid, cpis[0].properties).and_return(clouds[0])
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid, cpis[1].properties).and_return(clouds[1])
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[2].exec_path, Config.uuid, cpis[2].properties).and_return(clouds[2])
      }

      it 'returns all clouds from cpi config when asking for all configured clouds' do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path, Config.uuid, cpis[0].properties).and_return(clouds[0])
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid, cpis[1].properties).and_return(clouds[1])
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[2].exec_path, Config.uuid, cpis[2].properties).and_return(clouds[2])

        all_clouds = cloud_factory.all_configured_clouds
        expect(all_clouds.count).to eq(3)
        expect(all_clouds[0][:name]).to eq(cpis[0].name)
        expect(all_clouds[0][:cpi]).to eq(clouds[0])
        expect(all_clouds[1][:name]).to eq(cpis[1].name)
        expect(all_clouds[1][:cpi]).to eq(clouds[1])
        expect(all_clouds[2][:name]).to eq(cpis[2].name)
        expect(all_clouds[2][:cpi]).to eq(clouds[2])
      end

      it 'returns the cloud from cpi config when asking for a AZ with this cpi' do
        az = DeploymentPlan::AvailabilityZone.new('some-az', {}, cpis[0].name)
        expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path, Config.uuid, cpis[0].properties).and_return(clouds[0])

        cloud = cloud_factory.for_availability_zone!('some-az')
        expect(cloud).to eq(clouds[0])
      end

      it 'returns the cpi if asking for a given existing cpi' do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid, cpis[1].properties).and_return(clouds[1])
        cloud = cloud_factory.for_cpi('name2')
        expect(cloud).to eq(clouds[1])
      end

      it 'returns nil if asking for a nil cpi' do
        expect(cloud_factory.for_cpi(nil)).to be_nil
      end

      it 'returns nil if asking for a non-existing cpi' do
        expect(cloud_factory.for_cpi('name-notexisting')).to be_nil
      end

      it_behaves_like 'lookup for clouds'
      it_behaves_like 'lookup for clouds with fallback'
    end
  end
end