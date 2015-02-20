require 'spec_helper'

module Bosh::Deployer
  describe Configuration do
    let(:configuration_hash) do
      Psych.load_file(spec_asset('test-bootstrap-config.yml')).merge('dir' => dir)
    end
    let(:dir) { Dir.mktmpdir('bdc_spec') }

    subject(:config) { described_class.new }

    context 'when configuring with a basic configuration hash' do
      before do
        config.configure(configuration_hash)
      end

      after { FileUtils.remove_entry_secure(dir) }

      it 'should default agent properties' do
        properties = config.cloud_options['properties']
        expect(properties['agent']).to be_kind_of(Hash)
        expect(properties['agent']['mbus'].start_with?('https://')).to be(true)
        expect(properties['agent']['blobstore']).to be_kind_of(Hash)
      end

      it 'should default vm env properties' do
        env = config.env
        expect(env).to be_kind_of(Hash)
        expect(env).to have_key('bosh')
        expect(env['bosh']).to be_kind_of(Hash)
        expect(env['bosh']['password']).to be_nil
      end

      it 'should contain default vm resource properties' do
        resources = config.resources
        expect(resources).to be_kind_of(Hash)

        expect(resources['persistent_disk']).to be_kind_of(Integer)

        cloud_properties = resources['cloud_properties']
        expect(cloud_properties).to be_kind_of(Hash)

        %w(ram disk cpu).each do |key|
          expect(cloud_properties[key]).not_to be_nil
          expect(cloud_properties[key]).to be > 0
        end
      end

      describe '.networks' do
        it 'should map network properties to the bosh network' do
          networks = config.networks
          net = networks['bosh']
          expect(net).to be_kind_of(Hash)
          expect(net['default']).to match_array(%w(dns gateway))
          %w(cloud_properties netmask gateway ip dns type).each do |key|
            expect(net[key]).to eq(configuration_hash['network'][key])
          end
        end
      end
    end

    context 'when a deployment network is specified' do
      before do
        configuration_hash.merge!('deployment_network' => 'deployment network')
        config.configure(configuration_hash)
      end

      it 'includes the default bosh network and the deployment network' do
        networks = config.networks
        expect(networks['bosh']['default']).to match_array(%w(dns gateway))
        %w(cloud_properties netmask gateway ip dns type).each do |key|
          expect(networks['bosh'][key]).to eq(configuration_hash['network'][key])
        end

        expect(networks).to include('deployment' => 'deployment network')
      end
    end

    context 'when a vip is specified' do
      before do
        configuration_hash['network']['vip'] = '192.168.1.1'
        config.configure(configuration_hash)
      end

      it 'includes the default bosh network and a vip network' do
        networks = config.networks
        expect(networks['bosh']['default']).to match_array(%w(dns gateway))
        %w(cloud_properties netmask gateway ip dns type).each do |key|
          expect(networks['bosh'][key]).to eq(configuration_hash['network'][key])
        end

        vip_hash = {
          'vip' => {
            'ip' => '192.168.1.1',
            'type' => 'vip',
            'cloud_properties' => {
              'name' => 'VLAN2194'
            }
          }
        }
        expect(networks).to include(vip_hash)
      end
    end

    describe '#cpi_task_log' do
      before do
        config.configure(configuration_hash)
      end

      it 'returns nil' do
        expect(config.cpi_task_log).to be_nil
      end

      context 'when a cpi_log is specified' do
        before do
          configuration_hash['cloud']['properties']['cpi_log'] = 'fake-cpi-log'
          config.configure(configuration_hash)
        end

        it 'returns cpi log' do
          expect(config.cpi_task_log).to eq('fake-cpi-log')
        end
      end
    end

    describe 'services ips' do
      subject(:config) { described_class.new.configure(configuration_hash) }

      its(:internal_services_ip) { should eq('127.0.0.1') }

      context 'when bosh network is dynamic' do
        before do
          configuration_hash.merge!(
            'network' => {
              'type' => 'dynamic',
              'vip' => 'fake-vip-ip'
            }
          )
        end

        its(:agent_services_ip) { should eq('fake-vip-ip') }
        its(:client_services_ip) { should eq('fake-vip-ip') }
      end

      context 'when bosh network is manual' do
        before do
          configuration_hash.merge!(
            'network' => {
              'type' => 'manual',
              'ip' => 'fake-bosh-ip'
            }
          )
        end

        context 'when vip exists' do
          before do
            configuration_hash['network']['vip'] = 'fake-vip-ip'
          end

          its(:client_services_ip) { should eq('fake-vip-ip') }
        end

        context 'when vip does not exist' do
          its(:client_services_ip) { should eq('fake-bosh-ip') }
        end

        context 'when deployment network exists' do
          before do
            configuration_hash.merge!(
              'deployment_network' => {
                'ip' => 'fake-deployment-ip',
              }
            )
          end

          its(:agent_services_ip) { should eq('fake-deployment-ip') }
        end

        context 'when deployment network does not exist' do
          its(:agent_services_ip) { should eq('fake-bosh-ip') }
        end
      end
    end

    describe '#cloud' do
      before do
        allow(InfrastructureDefaults).to receive(:merge_for).and_return(configuration_hash)
        defaults = {
          'logging' => { 'level' => 'INFO' },
          'apply_spec' => { 'properties' => {}, 'agent' => {} },
        }
        configuration_hash.merge!(defaults)
        config.configure(configuration_hash)
      end

      it 'creates a cloud provider with the merged cloud properties' do
        expected_cloud_properties = configuration_hash['cloud']
        expect(Bosh::Clouds::Provider).to receive(:create)
                                          .with(expected_cloud_properties, anything)
                                          .once.and_return(:cloud)
        config.cloud
        expect(config.cloud).to eq(:cloud)
      end
    end
  end
end
