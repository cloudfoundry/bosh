require 'spec_helper'

module Bosh::Director
  describe CloudFactory do
    subject(:cloud_factory) { described_class.new(azs, parsed_cpi_config) }

    let(:azs) { {} }

    let(:default_cloud) { Config.cloud }
    let(:parsed_cpi_config) { CpiConfig::ParsedCpiConfig.new(cpis) }
    let(:cpis) { [] }
    let(:logger) { double(:logger, debug: nil) }

    context 'factory methods' do
      let(:cpi_config) { instance_double(Models::Config) }
      let(:cloud_config_content) {
        { 'azs' => cloud_config_azs}
      }
      let(:cloud_config_azs){
        [{ 'name' => 'z1', 'cpi' => 'cpi_z1'}, { 'name' => 'z2'}]
      }
      let(:cloud_config) { Models::Config.make(:cloud, content: YAML.dump(cloud_config_content)) }
      let(:deployment) { instance_double(Models::Deployment) }
      let(:cpi_manifest_parser) { instance_double(CpiConfig::CpiManifestParser) }

      before do
        allow(deployment).to receive(:cloud_configs).and_return([cloud_config])
        allow(deployment).to receive(:name).and_return('happy')
        allow(Api::CloudConfigManager).to receive(:interpolated_manifest).with([cloud_config], 'happy').and_return(cloud_config.raw_manifest)
        allow(CpiConfig::CpiManifestParser).to receive(:new).and_return(cpi_manifest_parser)
        allow(cpi_manifest_parser).to receive(:merge_configs).and_return(parsed_cpi_config)
        allow(cpi_manifest_parser).to receive(:parse).and_return(parsed_cpi_config)
        allow(cpi_config).to receive(:raw_manifest).and_return({})
      end

      describe '.create_from_deployment' do
        it 'constructs a cloud factory with all its dependencies from a deployment' do
          factory = described_class.create_from_deployment(deployment, [cpi_config])

          azs = factory.instance_variable_get(:@azs)
          expect(azs['z1'].name).to eq('z1')
          expect(azs['z1'].cpi).to eq('cpi_z1')
          expect(azs['z2'].name).to eq('z2')
          expect(azs['z2'].cpi).to eq(nil)
          expect(factory.instance_variable_get(:@parsed_cpi_config)).to eq(parsed_cpi_config)
        end

        it 'constructs a cloud factory without azs if no deployment is given' do
          deployment = nil
          factory = described_class.create_from_deployment(deployment, [cpi_config])

          expect(factory.instance_variable_get(:@azs)).to be_nil
          expect(factory.instance_variable_get(:@parsed_cpi_config)).to eq(parsed_cpi_config)
        end

        it 'constructs a cloud factory without parsed cpis if no cpi config is used' do
          factory = described_class.create_from_deployment(deployment, nil)

          expect(factory.instance_variable_get(:@azs)).to_not be_nil
          expect(factory.instance_variable_get(:@parsed_cpi_config)).to eq(nil)
        end

        context 'when no cloud config is provided' do
          let(:cloud_config) { Models::Config.make(:cloud, content: '--- {}') }

          it 'constructs a cloud factory without azs' do
            factory = described_class.create_from_deployment(deployment, [cpi_config])

            expect(factory.instance_variable_get(:@azs)).to be_nil
          end
        end
      end

      describe '.create_with_latest_configs' do
        before do
          allow(Bosh::Director::Models::Config).to receive(:latest_set).with('cpi').and_return([cpi_config])
          allow(Bosh::Director::Models::Config).to receive(:latest_set).with('cloud').and_return([cloud_config])
        end

        it 'constructs a cloud factory with all its dependencies from a deployment' do
          factory = described_class.create_with_latest_configs(deployment)

          azs = factory.instance_variable_get(:@azs)
          expect(azs['z1'].name).to eq('z1')
          expect(azs['z2'].name).to eq('z2')
          expect(factory.instance_variable_get(:@parsed_cpi_config)).to eq(parsed_cpi_config)
        end

        context 'when no deployment is given' do
          it 'constructs a cloud factory with all its dependencies without deployment' do
            allow(Api::CloudConfigManager).to receive(:interpolated_manifest).with([cloud_config], nil).and_return(cloud_config.raw_manifest)

            factory = described_class.create_with_latest_configs

            expect(factory.instance_variable_get(:@parsed_cpi_config)).to eq(parsed_cpi_config)
          end
        end
      end
    end

    shared_examples_for 'lookup for clouds' do

      it 'returns the default cloud from director config when asking for the cloud of an existing AZ without cpi' do
        cloud = cloud_factory.get_for_az('az-with-default-cpi')
        expect(cloud).to eq(default_cloud)
      end

      it 'raises an error if an AZ references a CPI that does not exist anymore' do
        # az = DeploymentPlan::AvailabilityZone.new('some-az', {}, 'not-existing-cpi')
        # expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)
        expect do
          cloud_factory.get_for_az('az-with-non-existing-cpi')
        end.to raise_error(
          "Failed to load CPI for AZ 'az-with-non-existing-cpi': CPI 'non-existing-cpi' not found in cpi-config#{config_error_hint}",
        )
      end

      it 'raises if asking for a cpi that is not defined in a cpi config' do
        expect do
          cloud_factory.get('name-notexisting')
        end.to raise_error(RuntimeError, "CPI 'name-notexisting' not found in cpi-config#{config_error_hint}")
      end

      it 'returns director default if asking for cpi with empty name' do
        expect(cloud_factory.get('')).to eq(default_cloud)
      end

      it 'returns default cloud if asking for a nil cpi' do
        expect(cloud_factory.get(nil)).to eq(default_cloud)
      end

      it 'returns the default cloud from director config when asking for the cloud of a nil AZ' do
        cloud = cloud_factory.get_for_az(nil)
        expect(cloud).to eq(default_cloud)
      end
    end

    context 'when not using cpi config' do
      let(:config_error_hint) { ' (because cpi-config is not set)' }
      let(:parsed_cpi_config) { nil }

      let(:azs) { {
          'az-with-default-cpi' => DeploymentPlan::AvailabilityZone.new('default-cpi', {}, nil),
          'az-with-non-existing-cpi' => DeploymentPlan::AvailabilityZone.new('non-existing-cpi', {}, 'non-existing-cpi'),
      } }

      before do
        expect(cloud_factory.uses_cpi_config?).to eq(false)
      end

      describe '#get_cpi_aliases' do
        it 'returns the empty cpi' do
          expect(cloud_factory.get_cpi_aliases('')).to eq([''])
        end
      end

      describe '#all_names' do
        it 'returns the default cpi' do
          expect(cloud_factory.all_names).to eq([''])
        end
      end

      it_behaves_like 'lookup for clouds'
    end

    context 'when using cpi config' do
      let(:config_error_hint) { '' }

      let(:cpis) do
        [
          CpiConfig::Cpi.new('name1', 'type1', nil, { 'prop1' => 'val1' }, {}),
          CpiConfig::Cpi.new('name2', 'type2', nil, { 'prop2' => 'val2' }, {}),
          CpiConfig::Cpi.new('name3', 'type3', nil, { 'prop3' => 'val3' }, {}),
        ]
      end

      let(:clouds) do
        [
          instance_double(Bosh::Cloud),
          instance_double(Bosh::Cloud),
          instance_double(Bosh::Cloud),
        ]
      end

      let(:azs) { {
          'some-az' => DeploymentPlan::AvailabilityZone.new('some-az', {}, cpis.first.name),
          'az-with-default-cpi' => DeploymentPlan::AvailabilityZone.new('default-cpi', {}, nil),
          'az-with-non-existing-cpi' => DeploymentPlan::AvailabilityZone.new('non-existing-cpi', {}, 'non-existing-cpi'),
      } }

      before do
        expect(cloud_factory.uses_cpi_config?).to be_truthy
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path, Config.uuid, cpis[0].properties).and_return(clouds[0])
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid, cpis[1].properties).and_return(clouds[1])
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[2].exec_path, Config.uuid, cpis[2].properties).and_return(clouds[2])
      end

      it 'returns the cloud from cpi config when asking for a AZ with this cpi' do
        # az = DeploymentPlan::AvailabilityZone.new('some-az', {}, cpis[0].name)
        # expect(cloud_planner).to receive(:availability_zone).with('some-az').and_return(az)
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path, Config.uuid, cpis[0].properties).and_return(clouds[0])

        cloud = cloud_factory.get_for_az('some-az')
        expect(cloud).to eq(clouds[0])
      end

      it 'returns the cpi if asking for a given existing cpi' do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid, cpis[1].properties).and_return(clouds[1])
        cloud = cloud_factory.get('name2')
        expect(cloud).to eq(clouds[1])
      end

      describe '#all_names' do
        it 'returns only the cpi-config cpis' do
          expect(cloud_factory.all_names).to eq(%w[name1 name2 name3])
        end
      end

      describe '#get_name_for_az' do
        it 'returns a cpi name when asking for an existing AZ' do
          cpi = cloud_factory.get_name_for_az('some-az')
          expect(cpi).to eq('name1')
        end
      end

      it_behaves_like 'lookup for clouds'
    end

    describe '#get_name_for_az' do
      it 'returns the default cpi name from director config when asking for the cloud of a nil AZ' do
        expect(cloud_factory.get_name_for_az(nil)).to eq('')
      end

      it 'returns the default cpi name from director config when asking for the cloud of an empty AZ' do
        expect(cloud_factory.get_name_for_az('')).to eq('')
      end

      it 'raises error when asking for a non-existing AZ' do
        expect do
          cloud_factory.get_name_for_az('some-az')
        end.to raise_error "AZ 'some-az' not found in cloud config"
      end

      context 'given a cloud config with an existing AZ without cpi' do
        let(:azs) { {
            'az-with-default-cpi' => DeploymentPlan::AvailabilityZone.new('default-cpi', {}, nil)
        } }

        it 'returns the default cloud from director config when asking for the cloud of an existing AZ without cpi' do
          expect(cloud_factory.get_name_for_az('az-with-default-cpi')).to eq('')
        end
      end

      context 'without given azs' do
        let(:azs) { nil }

        it 'raises an error if lookup of an AZ is needed' do
          expect do
            cloud_factory.get_name_for_az('some-az')
          end.to raise_error 'AZs must be given to lookup cpis from AZ'
        end
      end
    end

    describe '#get_cpi_aliases' do
      let(:cpis) { [CpiConfig::Cpi.new('name1', 'type1', nil, { 'prop1' => 'val1' }, migrated_from)] }
      let(:migrated_from) { [{ 'name' => 'some-cpi' }, { 'name' => 'another-cpi' }] }

      it 'returns the migrated_from names for the given cpi with the official name first' do
        expect(cloud_factory.get_cpi_aliases('name1')).to contain_exactly('name1', 'some-cpi', 'another-cpi')
      end
    end

    describe '.parse_cpi_configs' do
      let(:cpi_config1) { Bosh::Spec::NewDeployments.single_cpi_config('cpi-name1') }
      let(:cpi_config2) { Bosh::Spec::NewDeployments.single_cpi_config('cpi-name2') }
      let(:cpi_config3) { Bosh::Spec::NewDeployments.single_cpi_config('cpi-name3') }
      let(:cpi1) { Bosh::Director::Models::Config.make(type: 'cpi', name: 'cpi1', content: YAML.dump(cpi_config1)) }
      let(:cpi2) { Bosh::Director::Models::Config.make(type: 'cpi', name: 'cpi2', content: YAML.dump(cpi_config2)) }
      let(:cpi3) { Bosh::Director::Models::Config.make(type: 'cpi', name: 'cpi3', content: YAML.dump(cpi_config3)) }

      it 'returns all known cpis' do
        parsed_cpis = CloudFactory.parse_cpi_configs([cpi1, cpi2, cpi3])

        expect(parsed_cpis.cpis.size).to eq(3)
        expect(parsed_cpis.cpis.map(&:name)).to match_array(['cpi-name1', 'cpi-name2', 'cpi-name3'])
      end

      context 'when no cpis are known' do
        it 'returns nil' do
          expect(CloudFactory.parse_cpi_configs(nil)).to be(nil)
          expect(CloudFactory.parse_cpi_configs([])).to be(nil)
        end
      end
    end
  end
end
