require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe LinkLookupFactory do
      let(:consumed_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
      let(:link_path) {instance_double(Bosh::Director::DeploymentPlan::LinkPath)}
      let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner, use_short_dns_addresses?: false)}
      let(:link_network_options) {{:global_use_dns_entry => false}}

      describe '#create' do
        context 'when provider and consumer is from the SAME deployment' do
          before do
            allow(link_path).to receive(:deployment).and_return('dep-1')
            allow(deployment_plan).to receive(:name).and_return('dep-1')
            allow(deployment_plan).to receive(:instance_groups)
          end

          it 'returns a PlannerLinkLookup object' do
            planner_link_lookup = LinkLookupFactory.create(consumed_link, link_path, deployment_plan, link_network_options)
            expect(planner_link_lookup).to be_kind_of(PlannerLinkLookup)
          end
        end

        context 'when provider and consumer is from DIFFERENT deployment' do
          let(:provider_deployment_model) {instance_double(Bosh::Director::Models::Deployment)}

          before do
            allow(link_path).to receive(:deployment).and_return('dep-1')
            allow(deployment_plan).to receive(:name).and_return('dep-2')
            allow(Bosh::Director::Models::Deployment).to receive(:find).with({name: 'dep-1'}).and_return(provider_deployment_model)
          end

          it 'returns a DeploymentLinkSpecLookup object' do
            expect(provider_deployment_model).to receive(:link_spec).and_return({'meow' => 'cat'})

            deployment_link_lookup = LinkLookupFactory.create(consumed_link, link_path, deployment_plan, link_network_options)
            expect(deployment_link_lookup).to be_kind_of(DeploymentLinkSpecLookup)
          end

          context 'when provider deployment does not exist' do
            before do
              allow(Bosh::Director::Models::Deployment).to receive(:find).with({name: 'dep-1'}).and_return(nil)
            end

            it 'raises an error' do
              expect {
                LinkLookupFactory.create(consumed_link, link_path, deployment_plan, link_network_options)
              }.to raise_error Bosh::Director::DeploymentInvalidLink
            end
          end
        end
      end
    end

    describe PlannerLinkLookup do
      let(:consumed_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
      let(:link_path) {instance_double(Bosh::Director::DeploymentPlan::LinkPath)}
      let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner, use_short_dns_addresses?: false)}
      let(:link_network_options) {{:global_use_dns_entry => false}}
      let(:instance_group) {instance_double(Bosh::Director::DeploymentPlan::InstanceGroup)}
      let(:instance_groups) {[instance_group]}
      let(:job) {instance_double(Bosh::Director::DeploymentPlan::Job)}
      let(:jobs) {[job]}

      before do
        allow(deployment_plan).to receive(:instance_groups).and_return(instance_groups)
        allow(instance_group).to receive(:name).and_return('ig_1')
        allow(link_path).to receive(:job).and_return('ig_1')
      end

      describe '#find_link_spec' do
        context 'when instance group of link path cannot be found in deployment plan' do
          before do
            allow(deployment_plan).to receive(:instance_groups).and_return([])
          end

          it 'returns nil' do
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end
        end

        context 'when it is a disk link' do
          before do
            allow(link_path).to receive(:disk?).and_return(true)
            allow(link_path).to receive(:deployment).and_return('my-dep')
            allow(link_path).to receive(:name).and_return('my-disk')
          end

          it 'returns disk spec' do
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to eq({
                                                     'deployment_name' => 'my-dep',
                                                     'properties' => {'name' => 'my-disk'},
                                                     'networks' => [],
                                                     'instances' => []
                                                 })
          end
        end

        context 'when no job has the name specified in the link' do
          before do
            allow(link_path).to receive(:disk?).and_return(false)
            allow(instance_group).to receive(:jobs).and_return([])
          end

          it 'returns nil' do
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end
        end

        context 'when no job provide a link with the same name and type of link path' do
          let(:provided_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}

          before do
            allow(job).to receive(:name).and_return('job_name')
            allow(link_path).to receive(:template).and_return('job_name')
            allow(link_path).to receive(:disk?).and_return(false)
            allow(instance_group).to receive(:jobs).and_return(jobs)
            allow(job).to receive(:provided_links).with('ig_1').and_return([provided_link])
          end

          it 'returns nil if provided links are empty' do
            allow(job).to receive(:provided_links).with('ig_1').and_return([])
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end

          it 'returns nil if provided link name does not match' do
            allow(provided_link).to receive(:name).and_return('my_link')
            allow(link_path).to receive(:name).and_return('my_other_link')

            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end

          it 'returns nil if provided link type does not match' do
            allow(provided_link).to receive(:name).and_return('my_link')
            allow(link_path).to receive(:name).and_return('my_link')

            allow(provided_link).to receive(:type).and_return('my_type')
            allow(consumed_link).to receive(:type).and_return('my_other_type')

            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to be_nil
          end
        end

        context 'when a job provide a link with the same name and type of link path' do
          let(:provided_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
          let(:found_link) {instance_double(Bosh::Director::DeploymentPlan::Link)}
          let(:network_name) {'the-network'}
          let(:link_network_options) {{:preferred_network_name => network_name}}
          let(:link_network_options) do
            {
              :preferred_network_name => network_name,
              :global_use_dns_entry => false
            }
          end

          let(:mock_link_spec) {{
            'default_network' => network_name,
            'instances' => [
              {
                'name' => 'instance-1',
                'id' => 'instance-1-guid',
                'address' => 'dns-record-default',
                'addresses' => {network_name => 'ipaddr-1', 'net-2' => 'ipaddr-net-2'},
                'dns_addresses' => {network_name => 'dns-record-1', 'net-2' => 'dns-record-net-2'}
              }
            ]
          }}

          let(:expected_link_spec) {{
            'default_network' => network_name,
            'instances' => [
              {
                'name' => 'instance-1',
                'id' => 'instance-1-guid',
                'address' => 'ipaddr-1'
              }
            ]
          }}

          before do
            allow(link_path).to receive(:template).and_return('job_name')
            allow(link_path).to receive(:disk?).and_return(false)
            allow(link_path).to receive(:name).and_return('my_link')
            allow(link_path).to receive(:deployment).and_return('my_dep')

            allow(instance_group).to receive(:jobs).and_return(jobs)

            allow(job).to receive(:name).and_return('job_name')
            allow(job).to receive(:provided_links).with('ig_1').and_return([provided_link])

            allow(provided_link).to receive(:name).and_return('my_link')
            allow(provided_link).to receive(:type).and_return('my_type')
            allow(consumed_link).to receive(:type).and_return('my_type')

            allow(found_link).to receive(:spec).and_return(mock_link_spec)
          end

          it 'returns link spec' do
            expect(Bosh::Director::DeploymentPlan::Link).to receive(:new).with('my_dep', 'my_link', instance_group, job).and_return(found_link)
            look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
            expect(look_up.find_link_spec).to eq(expected_link_spec)
          end

          context 'link_network_options' do
            before do
              allow(Bosh::Director::DeploymentPlan::Link).to receive(:new).with('my_dep', 'my_link', instance_group, job).and_return(found_link)
            end

            context 'when global_use_dns_entry is TRUE' do
              let(:global_use_dns_entry) { true }

              let(:expected_link_spec) {{
                'default_network' => network_name,
                'instances' => [
                  {
                    'name' => 'instance-1',
                    'id' => 'instance-1-guid',
                    'address' => expected_address
                  }
                ]
              }}

              context 'when link_use_ip_address is nil' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => nil
                  }
                end
                let(:expected_address) { 'dns-record-1' }

                it 'sets spec.address to the corresponding value from dns_addresses' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end

                context 'when address returned is an IP' do
                  let(:logger) { double(:logger) }
                  let(:event_log) { double(:event_logger) }

                  let(:mock_link_spec) {{
                    'default_network' => network_name,
                    'instances' => [
                      {
                        'name' => 'instance-1',
                        'id' => 'instance-1-guid',
                        'address' => 'dns-record-default',
                        'addresses' => {network_name => 'ipaddr-1', 'net-2' => 'ipaddr-net-2'},
                        'dns_addresses' => {network_name => '1.1.1.1', 'net-2' => '2.2.2.2'}
                      }
                    ]
                  }}

                  let(:expected_address) { '1.1.1.1' }

                  before do
                    allow(logger).to receive(:warn)
                    allow(Config).to receive(:logger).and_return(logger)
                    allow(Config).to receive(:event_log).and_return(event_log)
                  end

                  it 'logs warning' do
                    log_message = 'DNS address not available for the link provider instance: instance-1/instance-1-guid'
                    expect(logger).to receive(:warn).with(log_message)
                    expect(event_log).to receive(:warn).with(log_message)

                    look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                    expect(look_up.find_link_spec).to eq(expected_link_spec)
                  end
                end
              end

              context 'when link_use_ip_address is TRUE' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => true
                  }
                end
                let(:expected_address) { 'ipaddr-1' }

                it 'sets spec.address to the corresponding value from addresses' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end
              end

              context 'when link_use_ip_address is FALSE' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => false
                  }
                end
                let(:expected_address) { 'dns-record-1' }

                it 'sets spec.address to the corresponding value from dns_addresses' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end
              end

              context 'when preferred network is set' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => 'net-2',
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => false
                  }
                end
                let(:expected_link_spec) {{
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'name' => 'instance-1',
                      'id' => 'instance-1-guid',
                      'address' => expected_address
                    }
                  ]
                }}
                let(:expected_address) { 'dns-record-net-2' }

                it 'sets spec.address to the corresponding value from chosen network' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end

                it 'fails if network name has no corresponding address' do
                  link_network_options[:preferred_network_name] = 'whatever-net'
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect{look_up.find_link_spec}.to raise_error "Provider link does not have network: 'whatever-net'"
                end
              end
            end

            context 'when global_use_dns_entry is FALSE' do
              let(:global_use_dns_entry) { false }

              let(:expected_link_spec) {{
                'default_network' => network_name,
                'instances' => [
                  {
                    'name' => 'instance-1',
                    'id' => 'instance-1-guid',
                    'address' => expected_address
                  }
                ]
              }}

              context 'when link_use_ip_address is nil' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => nil
                  }
                end
                let(:expected_address) { 'ipaddr-1' }

                it 'sets spec.address to the corresponding value from addresses' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end

                context 'when address returned is an IP' do
                  let(:logger) { double(:logger) }
                  let(:event_log) { double(:event_logger) }

                  before do
                    allow(logger).to receive(:warn)
                    allow(Config).to receive(:logger).and_return(logger)
                    allow(Config).to receive(:event_log).and_return(event_log)
                  end

                  it 'logs warning' do
                    log_message = 'IP address not available for the link provider instance: instance-1/instance-1-guid'
                    expect(logger).to receive(:warn).with(log_message)
                    expect(event_log).to receive(:warn).with(log_message)

                    look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                    expect(look_up.find_link_spec).to eq(expected_link_spec)
                  end
                end
              end

              context 'when link_use_ip_address is TRUE' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => true
                  }
                end
                let(:expected_address) { 'ipaddr-1' }

                it 'sets spec.address to the corresponding value from addresses' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end
              end

              context 'when link_use_ip_address is FALSE' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => false
                  }
                end
                let(:expected_address) { 'dns-record-1' }

                it 'sets spec.address to the corresponding value from dns_addresses' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end
              end

              context 'when preferred network is set' do
                let(:link_network_options) do
                  {
                    :preferred_network_name => network_name,
                    :global_use_dns_entry => global_use_dns_entry,
                    :link_use_ip_address => false
                  }
                end
                let(:expected_address) { 'dns-record-net-2' }
                let(:network_name) { 'net-2' }

                it 'sets spec.address to the corresponding value from chosen network' do
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect(look_up.find_link_spec).to eq(expected_link_spec)
                end

                it 'fails if network name has no corresponding address' do
                  link_network_options[:preferred_network_name] = 'whatever-net'
                  look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                  expect{look_up.find_link_spec}.to raise_error "Provider link does not have network: 'whatever-net'"
                end
              end
            end

            context 'when preferred_network_name is not passed' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false,
                }
              end

              let(:expected_link_spec) {{
                'default_network' => network_name,
                'instances' => [
                  {
                    'name' => 'instance-1',
                    'id' => 'instance-1-guid',
                    'address' => 'ipaddr-1'
                  }
                ]
              }}

              it 'chooses the default_network from link spec' do
                look_up = PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
                expect(look_up.find_link_spec).to eq(expected_link_spec)
              end
            end
          end
        end
      end
    end

    describe DeploymentLinkSpecLookup do
      let(:consumed_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
      let(:link_path) {instance_double(Bosh::Director::DeploymentPlan::LinkPath)}
      let(:link_network_options) {{:global_use_dns_entry => false}}

      before do
        allow(link_path).to receive(:name).and_return('my_link')
        allow(link_path).to receive(:job).and_return('ig_1')
        allow(link_path).to receive(:template).and_return('job_1')
        allow(consumed_link).to receive(:type).and_return('my_type')
      end

      describe '#find_link_spec' do
        context 'when instance_group can not be found in the link spec' do
          let(:link_spec) {{}}
          it 'returns nil' do
            lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
            expect(lookup.find_link_spec).to be_nil
          end
        end

        context 'when instance_group has no jobs' do
          let(:link_spec) {{"ig_1" => {}}}
          it 'returns nil' do
            lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
            expect(lookup.find_link_spec).to be_nil
          end
        end

        context 'when job has no link of type' do
          let(:link_spec) {{"ig_1" => {'job_1' => {}}}}

          it 'returns nil' do
            lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
            expect(lookup.find_link_spec).to be_nil
          end
        end

        context 'when provided link spec does NOT have default_network key' do
          let(:link_spec) do
            {
              'ig_1' => {
                'job_1' => {
                  'my_link' => {
                    'my_type' => {
                      'instances' => [
                        {
                          'address' => 'net-2-addr',
                          'addresses' => {
                            'net-1' => 'net-1-addr',
                            'net-2' => 'net-2-addr',
                            'net-3' => 'net-3-addr',
                          }
                        }
                      ]
                    }
                  }
                }
              }
            }
          end

          context 'when global_use_dns_entry is TRUE' do
            context 'when link_use_ip_address is nil' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => true
                }
              end

              let(:expected_spec) do
                {
                  'instances' => [
                    {
                      'address' => 'net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the spec.address' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end

            context 'when link_use_ip_address is TRUE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => true,
                  :link_use_ip_address => true
                }
              end

              it 'fails' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect {
                  lookup.find_link_spec
                }.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end

            context 'when link_use_ip_address is FALSE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => true,
                  :link_use_ip_address => false
                }
              end

              it 'fails' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect {
                  lookup.find_link_spec
                }.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end
          end

          context 'when global_use_dns_entry is FALSE' do
            context 'when link_use_ip_address is nil' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false
                }
              end

              let(:expected_spec) do
                {
                  'instances' => [
                    {
                      'address' => 'net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the spec.address' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end

            context 'when link_use_ip_address is TRUE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false,
                  :link_use_ip_address => true
                }
              end

              it 'fails' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect {
                  lookup.find_link_spec
                }.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end

            context 'when link_use_ip_address is FALSE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false,
                  :link_use_ip_address => false
                }
              end

              it 'fails' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect {
                  lookup.find_link_spec
                }.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end
          end

          context 'when preferred network is specified' do
            let(:link_network_options) do
              {
                :global_use_dns_entry => true,
                :preferred_network_name => 'net-3'
              }
            end

            let(:expected_spec) do
              {
                'instances' => [
                  {
                    'address' => 'net-3-addr',
                  }
                ]
              }
            end

            it 'picks the address from the preferred network' do
              lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
              expect(lookup.find_link_spec).to eq(expected_spec)
            end

            it 'fails if network name has no corresponding address' do
              link_network_options[:preferred_network_name] = 'whatever-net'
              lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
              expect{lookup.find_link_spec}.to raise_error "Provider link does not have network: 'whatever-net'"
            end
          end
        end

        context 'when provided link spec has default_network key' do
          let(:link_spec) do
            {
              'ig_1' => {
                'job_1' => {
                  'my_link' => {
                    'my_type' => {
                      'default_network' => 'net-2',
                      'instances' => [
                        {
                          'address' => 'net-2-addr',
                          'addresses' => {
                            'net-1' => 'net-1-addr',
                            'net-2' => 'net-2-addr',
                            'net-3' => 'net-3-addr',
                          },
                          'dns_addresses' => {
                            'net-1' => 'dns-net-1-addr',
                            'net-2' => 'dns-net-2-addr',
                            'net-3' => 'dns-net-3-addr',
                          }
                        }
                      ]
                    }
                  }
                }
              }
            }
          end

          context 'when global_use_dns_entry is TRUE' do
            context 'when link_use_ip_address is nil' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => true
                }
              end

              let(:expected_spec) do
                {
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'address' => 'dns-net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the dns_addresses for default network' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end

              context 'when address returned is an IP' do
                let(:logger) { double(:logger) }
                let(:event_log) { double(:event_logger) }

                let(:link_spec) do
                  {
                    'ig_1' => {
                      'job_1' => {
                        'my_link' => {
                          'my_type' => {
                            'default_network' => 'net-2',
                            'instances' => [
                              {
                                'id' => 'id-1',
                                'name' => 'name-1',
                                'address' => 'net-2-addr',
                                'addresses' => {
                                  'net-1' => '1.1.1.1',
                                  'net-2' => '2.2.2.2',
                                  'net-3' => '3.3.3.3',
                                },
                                'dns_addresses' => {
                                  'net-1' => '1.1.1.1',
                                  'net-2' => '2.2.2.2',
                                  'net-3' => '3.3.3.3',
                                }
                              }
                            ]
                          }
                        }
                      }
                    }
                  }
                end

                before do
                  allow(logger).to receive(:warn)
                  allow(Config).to receive(:logger).and_return(logger)
                  allow(Config).to receive(:event_log).and_return(event_log)
                end

                it 'logs warning' do
                  log_message = 'DNS address not available for the link provider instance: name-1/id-1'
                  expect(logger).to receive(:warn).with(log_message)
                  expect(event_log).to receive(:warn).with(log_message)

                  DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options).find_link_spec
                end
              end
            end

            context 'when link_use_ip_address is TRUE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => true,
                  :link_use_ip_address => true
                }
              end

              let(:expected_spec) do
                {
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'address' => 'net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the addresses' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end

              context 'when address returned is NOT an IP' do
                let(:logger) { double(:logger) }
                let(:event_log) { double(:event_logger) }

                let(:link_spec) do
                  {
                    'ig_1' => {
                      'job_1' => {
                        'my_link' => {
                          'my_type' => {
                            'default_network' => 'net-2',
                            'instances' => [
                              {
                                'id' => 'id-1',
                                'name' => 'name-1',
                                'address' => 'net-2-addr',
                                'addresses' => {
                                  'net-1' => 'a',
                                  'net-2' => 'b',
                                  'net-3' => 'c',
                                },
                                'dns_addresses' => {
                                  'net-1' => 'v',
                                  'net-2' => 'w',
                                  'net-3' => 'h',
                                }
                              }
                            ]
                          }
                        }
                      }
                    }
                  }
                end

                before do
                  allow(logger).to receive(:warn)
                  allow(Config).to receive(:logger).and_return(logger)
                  allow(Config).to receive(:event_log).and_return(event_log)
                end

                it 'logs warning' do
                  log_message = 'IP address not available for the link provider instance: name-1/id-1'
                  expect(logger).to receive(:warn).with(log_message)
                  expect(event_log).to receive(:warn).with(log_message)

                  DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options).find_link_spec
                end
              end
            end

            context 'when link_use_ip_address is FALSE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => true,
                  :link_use_ip_address => false
                }
              end

              let(:expected_spec) do
                {
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'address' => 'dns-net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the dns_addresses' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end
          end

          context 'when global_use_dns_entry is FALSE' do
            context 'when link_use_ip_address is nil' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false
                }
              end

              let(:expected_spec) do
                {
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'address' => 'net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the dns_addresses for default network' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end

            context 'when link_use_ip_address is TRUE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false,
                  :link_use_ip_address => true
                }
              end

              let(:expected_spec) do
                {
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'address' => 'net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the addresses' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end

            context 'when link_use_ip_address is FALSE' do
              let(:link_network_options) do
                {
                  :global_use_dns_entry => false,
                  :link_use_ip_address => false
                }
              end

              let(:expected_spec) do
                {
                  'default_network' => 'net-2',
                  'instances' => [
                    {
                      'address' => 'dns-net-2-addr',
                    }
                  ]
                }
              end

              it 'returns whatever is in the dns_addresses' do
                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end
          end

          context 'when preferred network is specified' do
            let(:link_network_options) do
              {
                :global_use_dns_entry => true,
                :preferred_network_name => 'net-3'
              }
            end

            let(:expected_spec) do
              {
                'default_network' => 'net-3',
                'instances' => [
                  {
                    'address' => 'dns-net-3-addr',
                  }
                ]
              }
            end

            it 'picks the address from the preferred network' do
              lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
              expect(lookup.find_link_spec).to eq(expected_spec)
            end

            it 'fails if network name has no corresponding address' do
              link_network_options[:preferred_network_name] = 'whatever-net'
              lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
              expect{lookup.find_link_spec}.to raise_error "Provider link does not have network: 'whatever-net'"
            end
          end
        end
      end
    end
  end
end
