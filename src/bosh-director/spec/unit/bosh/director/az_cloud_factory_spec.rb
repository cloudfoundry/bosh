require 'spec_helper'

module Bosh::Director
  describe AZCloudFactory do
    subject(:az_cloud_factory) { described_class.new(parsed_cpi_config, azs) }
    let(:default_cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:parsed_cpi_config) { nil }
    let(:cpis) { [] }
    let(:azs) do
      { 'some-az' => az }
    end
    let(:az) { instance_double(DeploymentPlan::AvailabilityZone, name: 'some-az') }

    before do
      allow(Bosh::Director::Config).to receive(:uuid).and_return('snoopy-uuid')
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(1)
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                             'snoopy-uuid',
                                                             instance_of(Logging::Logger),
                                                             stemcell_api_version: nil).and_return(default_cloud)
      allow(default_cloud).to receive(:info)
      allow(default_cloud).to receive(:request_cpi_api_version=)
    end

    context 'factory methods' do
      let(:cpi_config) { FactoryBot.create(:models_config_cpi) }
      let(:cloud_config) { FactoryBot.create(:models_config_cloud, content: '--- {"key": "value"}') }
      let(:deployment) { instance_double(Models::Deployment, teams: []) }
      let(:cpi_manifest_parser) { instance_double(CpiConfig::CpiManifestParser) }
      let(:cloud_manifest_parser) { instance_double(DeploymentPlan::CloudManifestParser) }

      before do
        allow(deployment).to receive(:cloud_configs).and_return([cloud_config])
        allow(deployment).to receive(:name).and_return('happy')
        allow(Api::CloudConfigManager).to receive(:interpolated_manifest).with([cloud_config], 'happy').and_return({})
        allow(CpiConfig::CpiManifestParser).to receive(:new).and_return(cpi_manifest_parser)
        allow(cpi_manifest_parser).to receive(:merge_configs).and_return(parsed_cpi_config)
        allow(cpi_manifest_parser).to receive(:parse).and_return(parsed_cpi_config)
        allow(cpi_config).to receive(:raw_manifest).and_return({})
        allow(DeploymentPlan::CloudManifestParser).to receive(:new).and_return(cloud_manifest_parser)
        allow(cloud_manifest_parser).to receive(:parse_availability_zones).and_return([az])
      end

      describe '.create_from_deployment' do
        it 'constructs a cloud factory with all its dependencies from a deployment' do
          expect(described_class).to receive(:new).with(parsed_cpi_config, azs)
          described_class.create_from_deployment(deployment)
        end

        context 'when no cloud config is provided' do
          let(:cloud_config) { FactoryBot.create(:models_config_cloud, content: '--- {}') }

          it 'constructs a cloud factory without azs' do
            expect(described_class).to receive(:new).with(parsed_cpi_config, nil)
            described_class.create_from_deployment(deployment)
          end
        end
      end

      describe '.create_with_latest_configs' do
        before do
          allow(Bosh::Director::Models::Config)
            .to receive(:latest_set_for_teams)
            .with('cloud')
            .and_return([cloud_config])
        end

        it 'constructs a cloud factory with all its dependencies from a deployment' do
          expect(described_class).to receive(:new).with(parsed_cpi_config, azs)
          described_class.create_with_latest_configs(deployment)
        end

        context 'when deployment has teams' do
          let(:footeam) { FactoryBot.create(:models_team, name: 'footeam') }
          let(:barteam) { FactoryBot.create(:models_team, name: 'barteam') }

          let!(:footeam_config) { FactoryBot.create(:models_config_cloud, team_id: footeam.id, content: '--- {"key": "value"}') }
          let!(:barteam_config) { FactoryBot.create(:models_config_cloud, team_id: barteam.id, content: '--- {"key": "value"}') }
          let(:deployment) { instance_double(Models::Deployment, teams: [footeam]) }

          before do
            allow(Api::CloudConfigManager)
              .to receive(:interpolated_manifest)
              .with([footeam_config], 'happy')
              .and_return({})
          end

          it 'uses only the cloud configs for those teams' do
            expect(Bosh::Director::Models::Config)
              .to receive(:latest_set_for_teams)
              .with('cloud', footeam)
              .and_return([footeam_config])
            described_class.create_with_latest_configs(deployment)
          end
        end
      end
    end

    context 'when using cpi config' do
      let(:config_error_hint) { '' }
      let(:az_without_cpi) { DeploymentPlan::AvailabilityZone.new('az-without-cpi', {}, nil) }
      let(:azs) do
        {
          'some-az' => az,
          'az-without-cpi' => az_without_cpi,
        }
      end
      let(:cpis) do
        [
          CpiConfig::Cpi.new('name1', 'type1', nil, { 'prop1' => 'val1' }, {}),
          CpiConfig::Cpi.new('name2', 'type2', nil, { 'prop2' => 'val2' }, {}),
          CpiConfig::Cpi.new('name3', 'type3', nil, { 'prop3' => 'val3' }, {}),
        ]
      end
      let(:az) { DeploymentPlan::AvailabilityZone.new('some-az', {}, cpis[0].name) }
      let(:clouds) do
        [
          instance_double(Bosh::Clouds::ExternalCpi),
          instance_double(Bosh::Clouds::ExternalCpi),
          instance_double(Bosh::Clouds::ExternalCpi),
        ]
      end
      let(:parsed_cpi_config) { CpiConfig::ParsedCpiConfig.new(cpis) }

      before do
        expect(az_cloud_factory.uses_cpi_config?).to be_truthy
        clouds.each do |cloud|
          allow(cloud).to receive(:info)
          allow(cloud).to receive(:request_cpi_api_version=)
        end
      end

      it 'returns the cloud from cpi config when asking for a AZ with this cpi' do
        cloud_wrapper = instance_double(Bosh::Clouds::ExternalCpiResponseWrapper)

        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path,
                                                                Config.uuid,
                                                                instance_of(Logging::Logger),
                                                                properties_from_cpi_config: cpis[0].properties,
                                                                stemcell_api_version: nil).and_return(clouds[0])
        expect(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).with(clouds[0], anything)
                                                                         .and_return(cloud_wrapper)

        cloud = az_cloud_factory.get_for_az('some-az')
        expect(cloud).to eq(cloud_wrapper)
      end

      describe '#get_name_for_az' do
        it 'returns a cpi name when asking for an existing AZ' do
          cpi = az_cloud_factory.get_name_for_az('some-az')
          expect(cpi).to eq('name1')
        end

        it 'raises an error if the AZ does not define a CPI' do
          expect do
            az_cloud_factory.get_name_for_az('az-without-cpi')
          end.to raise_error("AZ 'az-without-cpi' must specify a CPI when CPI config is defined.")
        end
      end

      context 'when an AZ references a CPI that does not exist anymore' do
        let(:az) { DeploymentPlan::AvailabilityZone.new('some-az', {}, 'not-existing-cpi') }

        it 'raises an error' do
          expect do
            az_cloud_factory.get_for_az('some-az')
          end.to raise_error(
            "Failed to load CPI for AZ 'some-az': CPI 'not-existing-cpi' not found in cpi-config#{config_error_hint}",
          )
        end
      end

      context 'when requesting a cloud instance associated with a specific stemcell api version' do
        it 'requests the correct one' do
          expect(az_cloud_factory).to receive(:get).with(anything, 432)

          az_cloud_factory.get_for_az('some-az', 432)
        end
      end

      it 'returns the default cloud from director config when asking for the cloud of a nil AZ' do
        cloud_wrapper = instance_double(Bosh::Clouds::ExternalCpiResponseWrapper)
        expect(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).with(default_cloud, anything).and_return(cloud_wrapper)

        cloud = az_cloud_factory.get_for_az(nil)

        expect(cloud).to eq(cloud_wrapper)
      end
    end

    describe '#get_name_for_az' do
      it 'returns the default cpi name from director config when asking for the cloud of a nil AZ' do
        expect(az_cloud_factory.get_name_for_az(nil)).to eq('')
      end

      it 'returns the default cpi name from director config when asking for the cloud of an empty AZ' do
        expect(az_cloud_factory.get_name_for_az('')).to eq('')
      end

      context 'when asking for a non-existing AZ' do
        let(:az) { nil }

        it 'raises error' do
          expect do
            az_cloud_factory.get_name_for_az('some-az')
          end.to raise_error "AZ 'some-az' not found in cloud config"
        end
      end

      context 'when asking for the cloud of an existing AZ without cpi' do
        let(:az) { DeploymentPlan::AvailabilityZone.new('some-az', {}, nil) }

        it 'returns the default cloud from director config ' do
          expect(az_cloud_factory.get_name_for_az('some-az')).to eq('')
        end
      end

      context 'without azs' do
        let(:azs) { nil }

        it 'raises an error if lookup of an AZ is needed' do
          expect do
            az_cloud_factory.get_name_for_az('some-az')
          end.to raise_error 'AZs must be given to lookup cpis from AZ'
        end
      end
    end
  end
end
