require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe LinkLookupFactory do
      let(:consumed_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
      let(:link_path) {instance_double(Bosh::Director::DeploymentPlan::LinkPath)}
      let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner)}
      let(:link_network_options) {{}}

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

    describe BaseLinkLookup do
      context '#update_addresses!' do
        context 'when use_dns_entry is not specified' do # Expecting DNS records
          let(:link_network_options) {{}}

          context 'when link_spec does not contain default_network key' do
            let(:link_spec) {{'instances' => []}}
            it 'does NOT raise an error' do
              expect {
                BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
              }.to_not raise_error
            end
          end
        end

        context 'when use_dns_entry is true' do # Expecting DNS records
          let(:link_network_options) {{:use_dns_entry => true}}
          let(:link_spec) {{'instances' => instances}}
          let(:instances) {[]}

          context 'when link_spec does not contain default_network key' do
            it 'does NOT raise an error' do
              expect {
                BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
              }.to_not raise_error
            end
          end

          context 'when the preferred_network_name is specified' do
            before do
              link_network_options[:preferred_network_name] = 'xyz'
            end

            context 'when the specified preferred_network_name does NOT exist' do
              before do
                link_spec['instances'] << {'address' => 'dns-address', 'addresses' => {'manual' => 'dns-address'}}
              end

              it 'raises an error' do
                expect {
                  BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                }.to raise_error Bosh::Director::LinkLookupError, 'Invalid network name: xyz'
              end
            end

            context 'when the specified preferred_network_name exists' do
              before do
                instances << {'address' => 'ip-address', 'addresses' => {'xyz' => 'dns-address'}}
              end

              it 'does NOT raise an error' do
                expect {
                  BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                }.to_not raise_error
              end

              it 'updates the address field with the preferred network address' do
                expected_result = {'instances' => [{'address' => 'dns-address', 'addresses' => {'xyz' => 'dns-address'}}]}

                BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                expect(link_spec).to eq(expected_result)
              end
            end

          end
        end

        context 'when use_dns_entry is false' do #Expecting ip addresses
          let(:link_network_options) {{:use_dns_entry => false}}
          let(:link_spec) {{'instances' => instances}}
          let(:instances) {[]}

          context 'when link_spec does not contain default_network key' do
            it 'raises an error' do
              expect {
                BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
              }.to raise_error Bosh::Director::LinkLookupError, 'Unable to retrieve default network from provider. Please redeploy provider deployment'
            end
          end

          context 'when link_spec contains default_network key' do
            before do
              link_spec['default_network'] = 'network1'
            end

            context 'when link_spec does not contain ip_addresses key for each instance' do
              let(:instances) {[{}]}
              it 'raises an error' do
                expect {
                  BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                }.to raise_error Bosh::Director::LinkLookupError, 'Unable to retrieve network addresses. Please redeploy provider deployment'
              end
            end

            context 'when link_spec contains ip_addresses key for each instance' do
              let(:instances) {[{'ip_addresses' => ip_addresses}]}
              let(:ip_addresses) {{'network1' => '10.0.0.0'}}

              it 'does not raise an error' do
                expect {
                  BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                }.to_not raise_error
              end

              it 'sets the address' do
                expected_result = {'default_network' => 'network1', 'instances' => [{'address' => '10.0.0.0', 'ip_addresses' => ip_addresses}]}
                BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                expect(link_spec).to eq(expected_result)
              end
            end
          end

          context 'when the preferred_network_name is specified' do
            before do
              link_network_options[:preferred_network_name] = 'xyz'
            end

            context 'when the specified preferred_network_name does NOT exist' do
              before do
                link_spec['instances'] << {'address' => 'ip-address', 'ip_addresses' => {'manual' => 'ip-address'}}
              end

              it 'raises an error' do
                expect {
                  BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                }.to raise_error Bosh::Director::LinkLookupError, 'Invalid network name: xyz'
              end
            end

            context 'when the specified preferred_network_name exists' do
              before do
                link_spec['instances'] << {'ip_addresses' => {'xyz' => 'ip-address'}}
              end

              it 'updates the address field with the preferred network address' do
                expected_result = {'instances' => [{'address' => 'ip-address', 'ip_addresses' => {'xyz' => 'ip-address'}}]}

                BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
                expect(link_spec).to eq(expected_result)
              end
            end
          end

          context 'when the ip_addresses field holds dns entries' do
            let(:logger) { double(:logger) }
            let(:event_log) { double(:event_logger) }

            before do
              allow(logger).to receive(:warn)
              allow(Config).to receive(:logger).and_return(logger)
              allow(Config).to receive(:event_log).and_return(event_log)

              link_spec['instances'] << {
                'name' => 'link-provider-name',
                'id' => 'link-provider-id',
                'address' => 'ip-address',
                'ip_addresses' => {'manual' => 'dns-address'}
              }
              link_spec['default_network'] = 'manual'
            end

            it 'logs the fact that ip_address could not be provided' do
              log_message = 'IP address not available for the link provider instance: link-provider-name/link-provider-id'
              expect(logger).to receive(:warn).with(log_message)
              expect(event_log).to receive(:warn).with(log_message)

              BaseLinkLookup.new(link_network_options).update_addresses!(link_spec)
            end
          end
        end
      end
    end

    describe PlannerLinkLookup do
      let(:consumed_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
      let(:link_path) {instance_double(Bosh::Director::DeploymentPlan::LinkPath)}
      let(:deployment_plan) {instance_double(Bosh::Director::DeploymentPlan::Planner)}
      let(:link_network_options) {{}}
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
          let(:link_network_options) {{:preferred_network_name => network_name, }}

          let(:mock_link_spec) {{
            'default_network' => network_name,
            'instances' => [
              {
                'name' => 'instance-1',
                'address' => 'dns-record-default',
                'addresses' => {network_name => 'dns-record-1'},
                'ip_addresses' => {network_name => 'ipaddr-1'}
              }
            ]
          }}

          let(:expected_link_spec) {{
            'default_network' => network_name,
            'instances' => [
              {
                'name' => 'instance-1',
                'address' => 'dns-record-1',
                'addresses' => {network_name => 'dns-record-1'},
                'ip_addresses' => {network_name => 'ipaddr-1'}
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
        end
      end
    end

    describe DeploymentLinkSpecLookup do
      let(:consumed_link) {instance_double(Bosh::Director::DeploymentPlan::TemplateLink)}
      let(:link_path) {instance_double(Bosh::Director::DeploymentPlan::LinkPath)}
      let(:link_network_options) {{}}

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

        context 'when a preferred address is specified' do
          let(:link_spec) {{
            "ig_1" => {
              'job_1' => {
                'my_link' => {
                  'my_type' => {
                    'default_network' => 'net-1',
                    'instances' => [
                      {
                        'addresses' => {
                          'net-1' => 'net-1-addr',
                          'net-2' => 'net-2-addr'
                        }
                      }
                    ]
                  }
                }
              }
            }
          }}
          let(:link_network_options) {{:preferred_network_name => 'net-2'}}

          it "overrides the address value with the preferred network's address" do
            expected_spec = {
              "default_network"=>"net-1",
              'instances' => [
                {
                  'address' => 'net-2-addr',
                  'addresses' => {
                    'net-1' => 'net-1-addr',
                    'net-2' => 'net-2-addr'
                  }
                }
              ]
            }

            lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
            expect(lookup.find_link_spec).to eq(expected_spec)
          end

          context 'when requesting ip only' do
            let(:link_network_options) {{:preferred_network_name => 'net-2', :use_dns_entry => false}}

            context 'ip_addresses section is found in the spec' do
              let(:link_spec) {{
                "ig_1" => {
                  'job_1' => {
                    'my_link' => {
                      'my_type' => {
                        'default_network' => 'net-1',
                        'instances' => [
                          {
                            'addresses' => {
                              'net-1' => 'net-1-addr',
                              'net-2' => 'net-2-addr'
                            },
                            'ip_addresses' => {
                              'net-1' => 'ip-addr-1',
                              'net-2' => 'ip-addr-2'
                            }
                          }
                        ]
                      }
                    }
                  }
                }
              }}

              it 'should return a spec with address field using entry from ip_address' do
                expected_spec = {
                  "default_network"=>"net-1",
                  'instances' => [
                    {
                      'address' => 'ip-addr-2',
                      'addresses' => {
                        'net-1' => 'net-1-addr',
                        'net-2' => 'net-2-addr'
                      },
                      'ip_addresses' => {
                        'net-1' => 'ip-addr-1',
                        'net-2' => 'ip-addr-2'
                      }
                    }
                  ]
                }

                lookup = DeploymentLinkSpecLookup.new(consumed_link, link_path, link_spec, link_network_options)
                expect(lookup.find_link_spec).to eq(expected_spec)
              end
            end
          end
        end
      end
    end
  end
end
