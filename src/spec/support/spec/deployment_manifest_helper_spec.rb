require 'spec_helper'

module Bosh::Spec
  RSpec.describe DeploymentManifestHelper do
    let(:expected_cloud_config) do
      {
        "networks" => [
          {
            "name" => "a",
            "subnets" => [expected_subnet]
          }
        ],
        "compilation" => { "workers" => 1, "network" => "a", "cloud_properties" => {} },
        "vm_types" => [{ "name" => "a", "cloud_properties" => {} }
        ]
      }
    end

    context 'when available_ips is 2' do
      let(:expected_subnet) do
        {
          "range" => "192.168.1.0/24",
          "gateway" => "192.168.1.1",
          "dns" => [],
          "static" => [],
          "reserved" => ["192.168.1.4-192.168.1.255"],
          "cloud_properties" => {},
        }
      end

      let(:cloud_config) { DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 2) }

      it 'creates the expected manifest' do
        first_subnet = cloud_config['networks'][0]['subnets'][0]

        expect(first_subnet).to eq(expected_subnet)
        expect(cloud_config).to eq(expected_cloud_config)
      end

      context 'with a specified range:' do
        let(:range) { '192.168.10.0/24' }

        let(:expected_subnet) do
          {
            "range" => "192.168.10.0/24",
            "gateway" => "192.168.10.1",
            "dns" => [],
            "static" => [],
            "reserved" => ["192.168.10.4-192.168.10.255"],
            "cloud_properties" => {},
          }
        end

        let(:cloud_config) { DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 2, range: range) }

        it 'creates the expected manifest' do
          first_subnet = cloud_config['networks'][0]['subnets'][0]

          expect(first_subnet).to eq(expected_subnet)
          expect(cloud_config).to eq(expected_cloud_config)
        end
      end
    end

    context 'when available_ips is 3 and shift_ip_range_by is 3' do
      let(:expected_subnet) do
        {
          "range" => "192.168.1.0/24",
          "gateway" => "192.168.1.1",
          "dns" => [],
          "static" => [],
          "reserved" => ["192.168.1.7-192.168.1.255", "192.168.1.2-192.168.1.3"],
          "cloud_properties" => {},
        }
      end

      let(:cloud_config) { DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 3, shift_ip_range_by: 2) }

      it 'creates the expected manifest' do
        first_subnet = cloud_config['networks'][0]['subnets'][0]

        expect(first_subnet).to eq(expected_subnet)
        expect(cloud_config).to eq(expected_cloud_config)
      end
    end
  end
end
