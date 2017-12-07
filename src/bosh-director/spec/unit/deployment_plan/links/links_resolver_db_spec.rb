require 'spec_helper'

describe 'links_resolver' do
  let(:deployment_name) {'fake-deployment'}
  let(:release_name) {'fake-release'}
  let(:deployment_model) {Bosh::Director::Models::Deployment.make(name: deployment_name)}

  let(:instance_group) do
    instance_group = instance_double(Bosh::Director::DeploymentPlan::InstanceGroup, {
      name: 'ig1',
      deployment_name: deployment_name,
      link_paths: []
    })
    allow(instance_group).to receive_message_chain(:persistent_disk_collection, :non_managed_disks).and_return([])
    allow(instance_group).to receive(:jobs).and_return(jobs)
    instance_group
  end

  let(:provider_job) do
    job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'j1')
    allow(job).to receive(:provided_links).and_return(provided_links)
    job
  end

  let(:jobs) do
    [provider_job]
  end

  let(:provided_links) do
    [
      Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1')
    ]
  end

  let(:consumer_job) do
    job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'j1')
    allow(job).to receive(:model_consumed_links).and_return(consumed_links)
    allow(job).to receive(:consumes_link_info).and_return(consumed_link_info)
    job
  end

  let(:consumed_link_info) do
    {}
  end

  let(:consumed_links) do
    [
      Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'c1')
    ]
  end

  let(:links_resolver) do
    Bosh::Director::DeploymentPlan::LinksResolver.new(deployment_plan, logger)
  end

  let(:deployment_plan) do
    deployment_plan = instance_double(Bosh::Director::DeploymentPlan::Planner, name: deployment_name, model: deployment_model)
    allow(deployment_plan).to receive(:add_link_provider)
    allow(deployment_plan).to receive(:add_link_consumer)
    deployment_plan
  end

  let(:link_spec) do
    {
      'deployment_name' => deployment_name,
      'domain' => 'bosh',
      'default_network' => 'net_a',
      'networks' => ['net_a', 'net_b'],
      'instance_group' => instance_group.name,
      'instances' => [],
    }
  end

  before do
    allow(Bosh::Director::DeploymentPlan::Link).to receive_message_chain(:new, :spec).and_return(link_spec)
  end

  context 'when an instance group is updated' do
    context 'and the provided link name specified in the release did not change' do
      it 'should update the previous provider' do
        providers = Bosh::Director::Models::LinkProvider

        links_resolver.add_providers(instance_group)

        expect(providers.count).to eq(1)
        original_provider_id = providers.first.id

        links_resolver.add_providers(instance_group)

        expect(providers.count).to eq(1)
        updated_provider_id = providers.first.id

        expect(updated_provider_id).to eq(original_provider_id)
      end
    end
  end

  context 'when a job provides two different names but is aliased to the same name' do
    let(:provided_links) do
      [
        Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1'),
        Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p2'),
      ]
    end

    it 'should create two providers in the database' do
      links_resolver.add_providers(instance_group)

      providers = Bosh::Director::Models::LinkProvider
      expect(providers.count).to eq(2)
    end
  end

  describe '#resolve' do
    context 'when job consumes link from another deployment' do
      context 'and the provider is using old content format' do
        let(:jobs) do
          [consumer_job]
        end

        let(:link_path) do
          instance_double(Bosh::Director::DeploymentPlan::LinkPath,
                          deployment: deployment_name,
                          instance_group: 'ig_1',
                          owner: 'job_1',
                          name: 'foo',
                          manual_spec: nil)
        end

        before do
          allow(instance_group).to receive(:link_path).and_return(link_path)
          allow(instance_group).to receive(:add_resolved_link)

          Bosh::Director::Models::LinkProvider.create(
            name: 'foo', # Alias
            deployment: deployment_model,
            instance_group: 'ig_1',
            link_provider_definition_name: 'original_provider_name',
            link_provider_definition_type: 'pt1',
            owner_object_name: 'job_1',
            owner_object_type: 'Job',
            shared: true,
            consumable: true,
            content: {
              'instances' =>
                [
                  {
                    'address' => 'net-2-addr',
                    'addresses' => {
                      'net-1' => 'net-1-addr',
                      'net-2' => 'net-2-addr',
                      'net-3' => 'net-3-addr',
                    }
                  }
                ]
            }.to_json
          )
        end

        context 'when global_use_dns_entry is TRUE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
          end

          context 'when link_use_ip_address is nil' do
            it 'returns whatever is in the spec.address' do
              links_resolver.resolve(instance_group)

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(link[:link_content]).to eq({'instances' => [{'address' => 'net-2-addr'}]}.to_json)
              expect(link[:created_at]).to be_a(Time)
            end
          end

          context 'when link_use_ip_address is TRUE' do
            let(:consumed_link_info) do
              {'ip_addresses' => true}
            end

            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
            end
          end

          context 'when link_use_ip_address is FALSE' do
            let(:consumed_link_info) do
              {'ip_addresses' => false}
            end


            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
            end
          end
        end

        context 'when global_use_dns_entry is FALSE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(false)
          end

          context 'when link_use_ip_address is nil' do

            it 'returns whatever is in the spec.address' do
              links_resolver.resolve(instance_group)

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(link[:link_content]).to eq({'instances' => [{'address' => 'net-2-addr'}]}.to_json)
              expect(link[:created_at]).to be_a(Time)
            end
          end

          context 'when link_use_ip_address is TRUE' do
            let(:consumed_link_info) do
              {'ip_addresses' => true}
            end

            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
            end
          end

          context 'when link_use_ip_address is FALSE' do
            let(:consumed_link_info) do
              {'ip_addresses' => false}
            end

            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
            end
          end
        end

        context 'when preferred network is specified' do
          let(:consumed_link_info) do
            {'network' => 'net-3'}
          end

          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
          end

          it 'picks the address from the preferred network' do
            links_resolver.resolve(instance_group)

            link = Bosh::Director::Models::Link.first
            expect(link[:id]).to eq(1)
            expect(link[:link_provider_id]).to eq(1)
            expect(link[:link_consumer_id]).to eq(1)
            expect(link[:name]).to eq("c1")
            expect(link[:link_content]).to eq({'instances' => [{'address' => 'net-3-addr'}]}.to_json)
            expect(link[:created_at]).to be_a(Time)
          end

          context 'with a bad network name' do
            let(:consumed_link_info) do
              {'network' => 'whatever-net'}
            end

            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error "Provider link does not have network: 'whatever-net'"
            end
          end
        end
      end

      context 'and the provider is using new content format' do
        let(:jobs) do
          [consumer_job]
        end

        let(:link_path) do
          instance_double(Bosh::Director::DeploymentPlan::LinkPath,
                          deployment: deployment_name,
                          instance_group: 'ig_1',
                          owner: 'job_1',
                          name: 'foo',
                          manual_spec: nil)
        end

        let(:addresses) do
          {
            'net-1' => 'net-1-addr',
            'net-2' => 'net-2-addr',
            'net-3' => 'net-3-addr',
          }
        end

        let(:dns_addresses) do
          {
            'net-1' => 'dns-net-1-addr',
            'net-2' => 'dns-net-2-addr',
            'net-3' => 'dns-net-3-addr',
          }
        end

        before do
          allow(instance_group).to receive(:link_path).and_return(link_path)
          allow(instance_group).to receive(:add_resolved_link)

          Bosh::Director::Models::LinkProvider.create(
            name: 'foo', # Alias
            deployment: deployment_model,
            instance_group: 'ig_1',
            link_provider_definition_name: 'original_provider_name',
            link_provider_definition_type: 'pt1',
            owner_object_name: 'job_1',
            owner_object_type: 'Job',
            shared: true,
            consumable: true,
            content: {
              'default_network' => 'net-2',
              'instances' => [
                {
                  'name' => 'name-1',
                  'id' => 'id-1',
                  'address' => 'net-2-addr',
                  'addresses' => addresses,
                  'dns_addresses' => dns_addresses
                }
              ]}.to_json
          )
        end

        context 'when global_use_dns_entry is TRUE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
          end

          context 'when link_use_ip_address is nil' do
            it 'returns whatever is in the dns_addresses for default network' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'dns-net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end

            context 'when address returned is an IP' do
              let(:logger) {double(:logger).as_null_object}
              let(:event_log) {double(:event_logger)}
              let(:addresses) do
                {
                  'net-1' => '1.1.1.1',
                  'net-2' => '2.2.2.2',
                  'net-3' => '3.3.3.3',
                }
              end
              let(:dns_addresses) do
                {
                  'net-1' => '1.1.1.1',
                  'net-2' => '2.2.2.2',
                  'net-3' => '3.3.3.3',
                }
              end

              before do
                allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
              end

              it 'logs warning' do
                log_message = 'DNS address not available for the link provider instance: name-1/id-1'
                expect(logger).to receive(:warn).with(log_message)
                expect(event_log).to receive(:warn).with(log_message)

                links_resolver.resolve(instance_group)
              end
            end
          end

          context 'when link_use_ip_address is TRUE' do
            let(:consumed_link_info) do
              {'ip_addresses' => true}
            end

            it 'returns whatever is in the addresses' do
              links_resolver.resolve(instance_group)

              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end

            context 'when address returned is NOT an IP' do
              let(:logger) {double(:logger).as_null_object}
              let(:event_log) {double(:event_logger)}

              before do
                allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
              end

              it 'logs warning' do
                log_message = 'IP address not available for the link provider instance: name-1/id-1'
                expect(logger).to receive(:warn).with(log_message)
                expect(event_log).to receive(:warn).with(log_message)

                links_resolver.resolve(instance_group)
              end
            end
          end

          context 'when link_use_ip_address is FALSE' do
            let(:consumed_link_info) do
              {'ip_addresses' => false}
            end

            it 'returns whatever is in the dns_addresses' do
              links_resolver.resolve(instance_group)

              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'dns-net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end
        end

        context 'when global_use_dns_entry is FALSE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(false)
          end

          context 'when link_use_ip_address is nil' do
            it 'returns whatever is in the addresses for default network' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end

          context 'when link_use_ip_address is TRUE' do
            let(:consumed_link_info) do
              {'ip_addresses' => true}
            end

            it 'returns whatever is in the addresses' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end

          context 'when link_use_ip_address is FALSE' do
            let(:consumed_link_info) do
              {'ip_addresses' => false}
            end

            it 'returns whatever is in the dns_addresses' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'dns-net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_id]).to eq(1)
              expect(link[:link_consumer_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end
        end

        context 'when preferred network is specified' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
          end

          let(:consumed_link_info) do
            {'network' => 'net-3'}
          end

          it 'picks the address from the preferred network' do
            links_resolver.resolve(instance_group)
            expected_link_content = {
              'default_network' => 'net-3',
              'instances' => [
                {
                  'name' => 'name-1',
                  'id' => 'id-1',
                  'address' => 'dns-net-3-addr'
                }
              ]
            }

            link = Bosh::Director::Models::Link.first
            expect(link[:id]).to eq(1)
            expect(link[:link_provider_id]).to eq(1)
            expect(link[:link_consumer_id]).to eq(1)
            expect(link[:name]).to eq("c1")
            expect(JSON.parse(link[:link_content])).to match(expected_link_content)
            expect(link[:created_at]).to be_a(Time)
          end

          context 'with a bad network name' do
            let(:consumed_link_info) do
              {'network' => 'whatever-net'}
            end

            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error "Provider link does not have network: 'whatever-net'"
            end
          end
        end
      end
    end
  end
end