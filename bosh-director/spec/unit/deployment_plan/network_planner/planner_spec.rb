require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkPlanner::Planner do
    include Bosh::Director::IpUtil

    subject(:planner) { NetworkPlanner::Planner.new(static_ip_repo, logger) }
    let(:static_ip_repo) { NetworkPlanner::StaticIpRepo.new([job_network], logger) }
    let(:instance_plan) { InstancePlan.new(existing_instance: nil, desired_instance: desired_instance, instance: instance) }
    let(:desired_instance) { DesiredInstance.new(job, nil, deployment_plan, instance_az) }
    let(:instance_model) { Bosh::Director::Models::Instance.make(deployment: deployment_model, vm: nil) }
    let(:job) { Job.new(logger) }
    let(:instance) { InstanceRepository.new(logger).fetch_existing(desired_instance, instance_model, {}) }
    let(:instance_az) { nil }
    let(:manual_network) { deployment_plan.network(network_name) }
    let(:job_network) { JobNetwork.new(network_name, static_ips, [], manual_network) }
    let(:static_ips) { [] }
    let(:network_name) { cloud_manifest['networks'].first['name'] }
    let(:cloud_manifest) do
      manifest = Bosh::Spec::Deployments.simple_cloud_config
      manifest['networks'].first['subnets'] = [z1_subnet_spec, z2_subnet_spec]
      manifest['availability_zones'] = [{'name' => 'z1'}, {'name' => 'z2'}]
      manifest
    end
    let(:deployment_model) do
      cloud_config = Bosh::Director::Models::CloudConfig.make(manifest: cloud_manifest)
      deployment_manifest = Bosh::Spec::Deployments.simple_manifest
      Bosh::Director::Models::Deployment.make(
        name: deployment_manifest['name'],
        manifest: YAML.dump(deployment_manifest),
        cloud_config: cloud_config,
      )
    end

    let(:deployment_plan) do
      planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(Bosh::Director::Config.event_log, logger)
      plan = planner_factory.create_from_model(deployment_model)
      plan
    end

    let(:z1_subnet_spec) do
      {
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.1',
        'static' => ['192.168.1.10', '192.168.1.11'],
        'availability_zone' => 'z1'
      }
    end

    let(:z2_subnet_spec) do
      {
        'range' => '192.168.2.0/24',
        'gateway' => '192.168.2.1',
        'static' => ['192.168.2.10', '192.168.2.11'],
        'availability_zone' => 'z2'
      }
    end

    before { fake_job }

    describe 'network_plan_with_dynamic_reservation' do
      it 'creates network plan for requested instance plan and network' do
        network_plan = planner.network_plan_with_dynamic_reservation(instance_plan, job_network)
        expect(network_plan.reservation.dynamic?).to be_truthy
        expect(network_plan.reservation.instance).to eq(instance)
        expect(network_plan.reservation.network).to eq(manual_network)
      end
    end

    describe 'network_plan_with_static_reservation' do
      let(:static_ips) { [ip_to_i('192.168.1.10'), ip_to_i('192.168.2.10')] }
      let(:instance_az) { AvailabilityZone.new('z2', {}) }

      it 'picks ip from subnet with AZ that matches instance AZ' do
        network_plan = planner.network_plan_with_static_reservation(instance_plan, job_network)
        expect(network_plan.reservation.static?).to be_truthy
        expect(network_plan.reservation.instance).to eq(instance)
        expect(network_plan.reservation.ip).to eq(ip_to_i('192.168.2.10'))
        expect(network_plan.reservation.network).to eq(manual_network)
      end

      context 'when instance does not specify desired AZ and subnets do not specify AZs' do
        let(:instance_az) { nil }
        let(:z1_subnet_spec) do
          {
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'static' => ['192.168.1.10', '192.168.1.11'],
          }
        end
        let(:z2_subnet_spec) do
          {
            'range' => '192.168.2.0/24',
            'gateway' => '192.168.2.1',
            'static' => ['192.168.2.10', '192.168.2.11']
          }
        end

        it 'picks ip from subnet with no az' do
          network_plan = planner.network_plan_with_static_reservation(instance_plan, job_network)
          expect(network_plan.reservation.static?).to be_truthy
          expect(network_plan.reservation.instance).to eq(instance)
          expect(network_plan.reservation.ip).to eq(ip_to_i('192.168.1.10'))
          expect(network_plan.reservation.network).to eq(manual_network)
        end
      end
    end
  end
end
