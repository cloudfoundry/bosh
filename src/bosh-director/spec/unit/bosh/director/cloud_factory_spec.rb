require 'spec_helper'

module Bosh::Director
  describe CloudFactory do
    subject(:cloud_factory) { described_class.new(parsed_cpi_config) }
    let(:cloud_wrapper) { instance_double(Bosh::Clouds::ExternalCpiResponseWrapper) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:parsed_cpi_config) { CpiConfig::ParsedCpiConfig.new(cpis) }
    let(:cpis) { [] }
    let(:cpi_api_version) { 1 }
    let(:cpi_info) do
      {
        'stemcell_formats' => 'some-stemcell-support-format',
        'api_version' => cpi_api_version,
      }
    end
    let(:stemcell_api_version) { nil }

    before do
      allow(Bosh::Director::Config).to receive(:uuid).and_return('snoopy-uuid')
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                             'snoopy-uuid',
                                                             instance_of(Logging::Logger),
                                                             stemcell_api_version: stemcell_api_version).and_return(cloud)
      allow(cloud).to receive(:info).and_return(cpi_info)
      allow(cloud).to receive(:request_cpi_api_version=)
    end

    describe 'CPI API version' do
      context 'info result includes CPI API version' do
        before do
          allow(cloud).to receive(:info).and_return(cpi_info)
        end

        it 'creates cloud with the CPI API version' do
          expect(cloud).to receive(:request_cpi_api_version=).with(cpi_info['api_version'])

          cloud_factory.get(nil, stemcell_api_version)
        end

        context 'when CPI version requested is higher than director supports' do
          let(:cpi_api_version) { 10 }

          it 'creates cloud with the director max supported version' do
            expect(cloud).to receive(:request_cpi_api_version=).with(Bosh::Director::Config.preferred_cpi_api_version)
            cloud_factory.get(nil, stemcell_api_version)
          end
        end
      end

      context 'old CPIs do not return the version from info' do
        let(:cpi_info) do
          {}
        end

        it 'creates cloud with CPI API version of 1' do
          expect(cloud).to receive(:request_cpi_api_version=).with(1)
          cloud_factory.get(nil, stemcell_api_version)
        end
      end
    end

    describe '.create' do
      let(:cpi_manifest_parser) { instance_double(CpiConfig::CpiManifestParser) }
      before do
        allow(CpiConfig::CpiManifestParser).to receive(:new).and_return(cpi_manifest_parser)
        allow(cpi_manifest_parser).to receive(:merge_configs).and_return(parsed_cpi_config)
        allow(cpi_manifest_parser).to receive(:parse).and_return(parsed_cpi_config)
      end

      context 'when there are cpi configs' do
        let(:cpi_config) { FactoryBot.create(:models_config_cpi) }

        before do
          allow(cpi_config).to receive(:raw_manifest).and_return({})
        end

        it 'constructs a cloud factory with the cpi configs' do
          expect(described_class).to receive(:new).with(parsed_cpi_config)

          described_class.create
        end
      end

      context 'when no cpis are configured' do
        it 'constructs a cloud factory with an empty cpi config' do
          expect(described_class).to receive(:new).with(nil)

          described_class.create
        end
      end
    end

    shared_examples_for 'lookup for clouds' do
      before do
        allow(cloud).to receive(:info).and_return({})
        allow(cloud).to receive(:request_cpi_api_version=)
      end

      it 'raises if asking for a cpi that is not defined in a cpi config' do
        expect do
          cloud_factory.get('name-notexisting')
        end.to raise_error(RuntimeError, "CPI 'name-notexisting' not found in cpi-config#{config_error_hint}")
      end

      it 'returns director default if asking for cpi with empty name' do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                                'snoopy-uuid',
                                                                instance_of(Logging::Logger),
                                                                stemcell_api_version: stemcell_api_version).and_return(cloud)
        expect(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).and_return(cloud_wrapper)
        expect(cloud_factory.get('')).to eq(cloud_wrapper)
      end

      it 'returns default cloud if asking for a nil cpi' do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                                'snoopy-uuid',
                                                                instance_of(Logging::Logger),
                                                                stemcell_api_version: stemcell_api_version).and_return(cloud)
        expect(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).and_return(cloud_wrapper)
        expect(cloud_factory.get(nil)).to eq(cloud_wrapper)
      end

      it "returns a new instance of the director's default cloud for each call" do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                                'snoopy-uuid',
                                                                instance_of(Logging::Logger),
                                                                stemcell_api_version: stemcell_api_version).twice
                                                          .and_return(cloud)

        cloud_factory.get(nil)
        cloud_factory.get(nil)
      end

      context 'when stemcell API version is passed' do
        let(:stemcell_api_version) { 25 }

        it 'creates the default external CPI instance with correct stemcell API version' do
          expect(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                                  'snoopy-uuid',
                                                                  instance_of(Logging::Logger),
                                                                  stemcell_api_version: stemcell_api_version).and_return(cloud)
          cloud_factory.get(nil, stemcell_api_version)
        end
      end
    end

    context 'when not using cpi config' do
      let(:config_error_hint) { ' (because cpi-config is not set)' }
      let(:parsed_cpi_config) { nil }

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
          instance_double(Bosh::Clouds::ExternalCpi),
          instance_double(Bosh::Clouds::ExternalCpi),
          instance_double(Bosh::Clouds::ExternalCpi),
        ]
      end

      before do
        expect(cloud_factory.uses_cpi_config?).to be_truthy
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[0].exec_path, Config.uuid,
                                                               instance_of(Logging::Logger),
                                                               properties_from_cpi_config: cpis[0].properties,
                                                               stemcell_api_version: nil).and_return(clouds[0])
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid,
                                                               instance_of(Logging::Logger),
                                                               properties_from_cpi_config: cpis[1].properties,
                                                               stemcell_api_version: nil).and_return(clouds[1])
        allow(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[2].exec_path, Config.uuid,
                                                               instance_of(Logging::Logger),
                                                               properties_from_cpi_config: cpis[2].properties,
                                                               stemcell_api_version: nil).and_return(clouds[2])

        clouds.each do |cloud|
          allow(cloud).to receive(:info)
          allow(cloud).to receive(:request_cpi_api_version=)
        end
      end

      it 'returns the cpi if asking for a given existing cpi' do
        expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid,
                                                                instance_of(Logging::Logger),
                                                                properties_from_cpi_config: cpis[1].properties,
                                                                stemcell_api_version: nil).and_return(clouds[1])
        allow(clouds[1]).to receive(:info).and_return({})
        expect(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).with(clouds[1],
                                                                               kind_of(Integer)).and_return(cloud_wrapper)
        cloud = cloud_factory.get('name2')
        expect(cloud).to eq(cloud_wrapper)
      end

      context 'when stemcell API version is passed' do
        it 'returns the cpi with correct stemcell API version if asking for a given existing cpi' do
          expect(Bosh::Clouds::ExternalCpi).to receive(:new).with(cpis[1].exec_path, Config.uuid,
                                                                  instance_of(Logging::Logger),
                                                                  properties_from_cpi_config: cpis[1].properties,
                                                                  stemcell_api_version: 34).and_return(clouds[1])
          expect(Bosh::Clouds::ExternalCpiResponseWrapper).to receive(:new).with(clouds[1],
                                                                                 kind_of(Integer)).and_return(cloud_wrapper)
          cloud = cloud_factory.get('name2', 34)
          expect(cloud).to eq(cloud_wrapper)
        end
      end

      describe '#all_names' do
        it 'returns only the cpi-config cpis' do
          expect(cloud_factory.all_names).to eq(%w[name1 name2 name3])
        end
      end

      describe '#get_cpi_aliases' do
        let(:cpi) { CpiConfig::Cpi.new('name1', 'type1', nil, { 'prop1' => 'val1' }, migrated_from) }
        let(:migrated_from) { [{ 'name' => 'some-cpi' }, { 'name' => 'another-cpi' }] }

        before do
          cpis[0] = cpi
        end

        it 'returns the migrated_from names for the given cpi with the official name first' do
          expect(cloud_factory.get_cpi_aliases('name1')).to contain_exactly('name1', 'some-cpi', 'another-cpi')
        end

        it 'raises if asking for aliases for a cpi that is not defined in a cpi config' do
          expect do
            cloud_factory.get_cpi_aliases('name-notexisting')
          end.to raise_error(RuntimeError, "CPI 'name-notexisting' not found in cpi-config")
        end
      end

      it_behaves_like 'lookup for clouds'
    end
  end
end
