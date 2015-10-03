require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstancePlan do
    let(:job) { Job.parse(deployment_plan, job_spec, BD::Config.event_log, logger) }
    let(:instance_model) { BD::Models::Instance.make(bootstrap: false, deployment: deployment_model, uuid: 'uuid-1') }
    let(:desired_instance) { DesiredInstance.new(job, current_state, deployment_plan, availability_zone) }
    let(:current_state) { {'current' => 'state', 'job' => job_spec } }
    let(:availability_zone) { AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:instance) { Instance.new(job, 1, 'started', deployment_plan, current_state, availability_zone, true, logger) }
    let(:network_resolver) { GlobalNetworkResolver.new(deployment_plan) }
    let(:network) { ManualNetwork.new(network_spec, [availability_zone], network_resolver, logger) }
    let(:reservation) {
      reservation = BD::DesiredNetworkReservation.new_dynamic(instance, network)
      reservation.resolve_ip('192.168.1.3')
      reservation
    }
    let(:network_plan) { NetworkPlan.new(reservation: reservation) }
    let(:instance_plan) { InstancePlan.new(existing_instance: existing_instance, desired_instance: desired_instance, instance: instance, network_plans: [network_plan]) }
    let(:existing_instance) { instance_model }

    let(:job_spec) { Bosh::Spec::Deployments.simple_manifest['jobs'].first }
    let(:network_spec) { Bosh::Spec::Deployments.simple_cloud_config['networks'].first }
    let(:cloud_config_manifest) { Bosh::Spec::Deployments.simple_cloud_config }
    let(:deployment_manifest) { Bosh::Spec::Deployments.simple_manifest }
    let(:deployment_model) do
      cloud_config = BD::Models::CloudConfig.make(manifest: cloud_config_manifest)
      BD::Models::Deployment.make(
        name: deployment_manifest['name'],
        manifest: YAML.dump(deployment_manifest),
        cloud_config: cloud_config,
      )
    end

    let(:deployment_plan) do
      planner_factory = PlannerFactory.create(BD::Config.event_log, logger)
      plan = planner_factory.create_from_model(deployment_model)
      plan.bind_models
      plan
    end

    before do
      fake_locks
      prepare_deploy(deployment_manifest, cloud_config_manifest)
      instance.bind_existing_instance_model(instance_model)
      job.add_instance_plans([instance_plan])
    end

    context 'when there have been changes on the instance' do
      context '#bootstrap_changed?' do
        context 'when bootstrap node changes' do
          before do
            desired_instance.mark_as_bootstrap
          end

          it 'adds :bootstrap to the set of changes' do
            expect(instance_plan.changes).to include(:bootstrap)
          end
        end

        context 'when bootstrap node remains the same' do
          it 'changes do not include bootstrap' do
            expect(instance_plan.changes).not_to include(:bootstrap)
          end
        end

        context 'when instance plan does not have existing instance' do
          let(:existing_instance) { nil }

          it 'changes include bootstrap' do
            expect(instance_plan.changes).to include(:bootstrap)
          end
        end
      end

      describe '#dns_changed?' do
        describe 'when the index dns record for the instance is not found' do
          before do
            BD::Models::Dns::Record.create(:name => 'uuid-1.foobar.a.simple.fake-dns', :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name '1.foobar.a.simple.fake-dns' and ip '192.168.1.3' was not found in the db.")
            instance_plan.dns_changed?
          end
        end

        describe 'when the id dns record for the instance is not found' do
          before do
            BD::Models::Dns::Record.create(:name => '1.foobar.a.simple.fake-dns', :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return true' do
            expect(instance_plan.dns_changed?).to be(true)
          end

          it 'should log the dns changes' do
            expect(logger).to receive(:debug).with("dns_changed? The requested dns record with name 'uuid-1.foobar.a.simple.fake-dns' and ip '192.168.1.3' was not found in the db.")
            instance_plan.dns_changed?
          end
        end

        describe 'when the dns records for the instance are found' do
          before do
            BD::Models::Dns::Record.create(:name => '1.foobar.a.simple.fake-dns', :type => 'A', :content => '192.168.1.3')
            BD::Models::Dns::Record.create(:name => "#{instance.uuid}.foobar.a.simple.fake-dns", :type => 'A', :content => '192.168.1.3')
          end

          it '#dns_changed? should return false' do
            expect(instance_plan.dns_changed?).to be(false)
          end
        end
      end
    end
  end
end
