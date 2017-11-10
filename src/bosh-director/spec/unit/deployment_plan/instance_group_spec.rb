require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstanceGroup do
  subject(:instance_group) { Bosh::Director::DeploymentPlan::InstanceGroup.parse(plan, spec, event_log, logger, parse_options) }
  let(:parse_options) { {} }
  let(:event_log)  { instance_double('Bosh::Director::EventLog::Log', warn_deprecated: nil) }

  let(:deployment) { Bosh::Director::Models::Deployment.make }
  let(:fake_ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProvider, reserve: nil, reserve_existing_ips: nil) }
  let(:plan) do
    instance_double('Bosh::Director::DeploymentPlan::Planner',
      model: deployment,
      name: deployment.name,
      ip_provider: fake_ip_provider,
      releases: {}
    )
  end
  let(:vm_type) { Bosh::Director::DeploymentPlan::VmType.new({'name' => 'dea'}) }
  let(:stemcell) { instance_double('Bosh::Director::DeploymentPlan::Stemcell') }
  let(:env) { instance_double('Bosh::Director::DeploymentPlan::Env') }

  let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network-name', validate_reference_from_job!: true, has_azs?: true) }

  let(:foo_properties) do
    {
      'dea_min_memory' => {'default' => 512},
      'deep_property.dont_override' => {'default' => 'ghi'},
      'deep_property.new_property' => {'default' => 'jkl'}
    }
  end

  let(:bar_properties) do
    {'dea_max_memory' => {'default' => 2048}}
  end

  let(:release1_foo_job) do
    r = Bosh::Director::DeploymentPlan::Job.new(release1, 'foo', 'story-152729032')
    r.bind_existing_model(release1_foo_job_model)
    r
  end
  let(:release1_foo_job_model) { Bosh::Director::Models::Template.make(name: 'foo', release: release1_model) }

  let(:release1_bar_job) do
    r = Bosh::Director::DeploymentPlan::Job.new(release1, 'bar', 'story-152729032')
    r.bind_existing_model(release1_bar_job_model)
    r
  end
  let(:release1_bar_job_model) { Bosh::Director::Models::Template.make(name: 'bar', release: release1_model) }

  let(:release1_package1_model) { Bosh::Director::Models::Package.make(name: 'same-name', release: release1_model, fingerprint: 'abc123') }

  let(:release1) do
    Bosh::Director::DeploymentPlan::ReleaseVersion.new(deployment, {
      'name' => 'release1',
      'version' => '1',
    })
  end

  let(:release1_model) { Bosh::Director::Models::Release.make(name: 'release1') }
  let(:release1_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '1', release: release1_model) }
  let(:logger) { double(:logger).as_null_object }

  before do
    allow(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)

    allow(plan).to receive(:networks).and_return([network])
    allow(plan).to receive(:vm_type).with('dea').and_return vm_type
    allow(plan).to receive(:stemcell).with('dea').and_return stemcell
    allow(plan).to receive(:update)

    allow(release1).to receive(:get_or_create_template).with('foo').and_return(release1_foo_job)
    allow(release1).to receive(:get_or_create_template).with('bar').and_return(release1_bar_job)

    allow(release1_foo_job).to receive(:properties)
    allow(release1_bar_job).to receive(:properties)

    allow(release1_foo_job).to receive(:add_properties)
    allow(release1_bar_job).to receive(:add_properties)
    allow(deployment).to receive(:current_variable_set).and_return(Bosh::Director::Models::VariableSet.make)

    release1_version_model.add_template(release1_foo_job_model)
    release1_version_model.add_template(release1_bar_job_model)
    release1_version_model.add_package(release1_package1_model)
  end

  describe '#parse' do
    let(:spec) do
      {
        'name' => 'foobar',
        'release' => 'appcloud',
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'env' => {'key' => 'value'},
        'instances' => 1,
        'networks'  => [{'name' => 'fake-network-name'}],
        'properties' => props,
        'template' => %w(foo bar),
        'update' => update
      }
    end

    let(:props) do
      {
        'cc_url' => 'www.cc.com',
        'deep_property' => {
          'unneeded' => 'abc',
          'dont_override' => 'def'
        },
        'dea_max_memory' => 1024
      }
    end

    before do
      allow(plan).to receive(:properties).and_return(props)
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
    end

    context 'when parse_options contain canaries' do
      let(:parse_options) { {'canaries' => 42} }
      let(:update) { { 'canaries' => 22 } }

      it 'overrides canaries value with one from parse_options' do
        expect(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)
          .with( parse_options, nil)
        instance_group
      end
    end

    context 'when parse_options contain max_in_flight' do
      let(:parse_options) { {'max_in_flight' => 42} }
      let(:update) { { 'max_in_flight' => 22 } }

      it 'overrides max_in_flight value with one from parse_options' do
        expect(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)
          .with( parse_options, nil)
        instance_group
      end
    end
  end

  describe '#bind_properties' do
    let(:spec) do
      {
        'name' => 'foobar',
        'release' => 'appcloud',
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'env' => {'key' => 'value'},
        'instances' => 1,
        'networks'  => [
          {'name' => 'fake-network-name', 'default' => ['dns', 'gateway']},
          {'name' => 'fake-network-name2'}
        ],
        'template' => %w(foo bar),
      }
    end

    let(:foo_properties) do
      {
        'foobar' => {
          'cc_url' => 'www.cc.com',
          'deep_property' => {
            'unneeded' => 'abc',
            'dont_override' => 'def'
          }
        }
      }
    end

    let(:bar_properties) do
      {
        'foobar' => {
          'vroom' => 'smurf',
          'dea_max_memory' => 1024
        }
      }
    end

    let(:options) do
      {
        :dns_record_names => [
          "*.foobar.fake-network-name.#{deployment.name}.bosh",
          "*.foobar.fake-network-name2.#{deployment.name}.bosh"
        ]
      }
    end

    let(:network2) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'fake-network-name2', validate_reference_from_job!: true, has_azs?: true) }

    before do
      allow(plan).to receive(:networks).and_return([network, network2])

      allow(plan).to receive(:properties).and_return({})
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
      allow(release1_foo_job).to receive(:properties).and_return(foo_properties)
      allow(release1_bar_job).to receive(:properties).and_return(bar_properties)
    end

    it 'binds all job properties with correct parameters' do
      expect(release1_foo_job).to receive(:bind_properties).with('foobar', deployment.name, options)
      expect(release1_bar_job).to receive(:bind_properties).with('foobar', deployment.name, options)

      instance_group.bind_properties

      expect(instance_group.properties).to eq(
                                             {
                                               'foo' => {
                                                 'cc_url' => 'www.cc.com',
                                                 'deep_property' => {
                                                   'unneeded' => 'abc',
                                                   'dont_override' => 'def'
                                                 }
                                               },
                                               'bar' => {
                                                 'vroom' => 'smurf',
                                                 'dea_max_memory' =>1024
                                               }
                                             }
                                           )
    end
  end

  describe '#validate_package_names_do_not_collide!' do
    before do
      allow(plan).to receive(:properties).and_return({})
      allow(plan).to receive(:release).with('release1').and_return(release1)
    end

    context 'when the templates are from the same release' do
      let(:spec) do
        {
          'name' => 'foobar',
          'templates' => [
            { 'name' => 'foo', 'release' => 'release1' },
            { 'name' => 'bar', 'release' => 'release1' },
          ],
          'vm_type' => 'dea',
          'stemcell' => 'dea',
          'env' => {'key' => 'value'},
          'instances' => 1,
          'networks' => [{ 'name' => 'fake-network-name' }],
        }
      end

      context 'when templates depend on packages with the same name (i.e. same package)' do
        before do
          release1_foo_job_model.package_names = ['same-name']
          release1_foo_job_model.save
          release1_bar_job_model.package_names = ['same-name']
          release1_bar_job_model.save
          allow(plan).to receive(:releases).with(no_args).and_return([release1])
        end

        it 'does not raise an error' do
          expect { instance_group.validate_package_names_do_not_collide! }.to_not raise_error
        end
      end
    end

    context 'when the templates are from different releases' do
      let(:release2) do
        Bosh::Director::DeploymentPlan::ReleaseVersion.new(deployment, {
          'name' => 'release2',
          'version' => '1',
        })
      end
      let(:release2_bar_job) do
        r = Bosh::Director::DeploymentPlan::Job.new(release2, 'bar', 'story-152729032')
        r.bind_existing_model(release2_bar_job_model)
        r
      end
      let(:release2_bar_job_model) { Bosh::Director::Models::Template.make(name: 'bar', release: release2_model) }
      let(:release2_model) { Bosh::Director::Models::Release.make(name: 'release2') }
      let(:release2_version_model) { Bosh::Director::Models::ReleaseVersion.make(release: release2_model, version: 1) }
      let(:release2_package1_model) { Bosh::Director::Models::Package.make(name: release2_package1_name, release: release2_model, fingerprint: release2_package1_fingerprint) }
      let(:release2_package1_fingerprint) { '987asd' }
      let(:release2_package1_name) { 'another-name' }

      before do
        release2_version_model.add_template(release2_bar_job_model)
        release2_version_model.add_package(release2_package1_model)

        release1_foo_job_model.package_names = [release1_package1_model.name]
        release1_foo_job_model.save
        release2_bar_job_model.package_names = [release2_package1_model.name]
        release2_bar_job_model.save

        allow(plan).to receive(:releases).with(no_args).and_return([release1, release2])
        allow(plan).to receive(:release).with('release2').and_return(release2)

        allow(release2).to receive(:get_or_create_template).with('bar').and_return(release2_bar_job)
      end

      let(:spec) do
        {
          'name' => 'foobar',
          'templates' => [
            { 'name' => 'foo', 'release' => 'release1' },
            { 'name' => 'bar', 'release' => 'release2', 'links' => {'a' => 'x.y.z.zz'}},
          ],
          'vm_type' => 'dea',
          'stemcell' => 'dea',
          'env' => {'key' => 'value'},
          'instances' => 1,
          'networks' => [{'name' => 'fake-network-name'}],
        }
      end

      context 'when templates do not depend on packages with the same name' do
        it 'does not raise an exception' do
          expect { instance_group.validate_package_names_do_not_collide! }.to_not raise_error
        end
      end

      context 'when templates depend on packages with the same name' do
        let(:release2_package1_name) { 'same-name' }

        context 'fingerprints are different' do
          let(:release2_package1_fingerprint) { '987asd' }

          it 'raises an exception because agent currently cannot collocate similarly named packages from multiple releases' do
            expect {
              instance_group.validate_package_names_do_not_collide!
            }.to raise_error(
              Bosh::Director::JobPackageCollision,
              "Package name collision detected in instance group 'foobar': job 'release1/foo' depends on package 'release1/same-name',"\
              " job 'release2/bar' depends on 'release2/same-name'. " +
                'BOSH cannot currently collocate two packages with identical names from separate releases.',
            )
          end
        end

        context 'fingerprints are the same' do
          let(:release2_package1_fingerprint) { 'abc123' }

          it 'does not raise an exception' do
            instance_group.validate_package_names_do_not_collide!
          end
        end
      end
    end
  end

  describe '#spec' do
    let(:spec) do
      {
        'name' => 'job1',
        'template' => 'foo',
        'release' => 'release1',
        'instances' => 1,
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'env' => {'key' => 'value'},
        'networks'  => [{'name' => 'fake-network-name'}],
      }
    end

    before do
      allow(release1).to receive(:name).and_return('cf')

      allow(release1_foo_job).to receive(:version).and_return('200')
      allow(release1_foo_job).to receive(:sha1).and_return('fake_sha1')
      allow(release1_foo_job).to receive(:blobstore_id).and_return('blobstore_id_for_foo_job')
      allow(release1_foo_job).to receive(:properties).and_return({})

      allow(plan).to receive(:releases).with(no_args).and_return([release1])
      allow(plan).to receive(:release).with('release1').and_return(release1)
      allow(plan).to receive(:properties).with(no_args).and_return({})
    end

    context "when a template has 'logs'" do
      before do
        allow(release1_foo_job).to receive(:logs).and_return(
          {
            'filter_name1' => 'foo/*',
          }
        )
      end

      it 'contains name, release for the job, and logs spec for each template' do
        expect(instance_group.spec).to eq(
          {
            'name' => 'job1',
            'templates' => [
              {
                'name' => 'foo',
                'version' => '200',
                'sha1' => 'fake_sha1',
                'blobstore_id' => 'blobstore_id_for_foo_job',
                'logs' => {
                  'filter_name1' => 'foo/*',
                },
              },
            ],
            'template' => 'foo',
            'version' => '200',
            'sha1' => 'fake_sha1',
            'blobstore_id' => 'blobstore_id_for_foo_job',
            'logs' => {
              'filter_name1' => 'foo/*',
            }
          }
        )
      end
    end

    context "when a template does not have 'logs'" do
      before do
        allow(release1_foo_job).to receive(:logs)
      end

      it 'contains name, release and information for each template' do
        expect(instance_group.spec).to eq(
          {
            'name' => 'job1',
            'templates' =>[
              {
                'name' => 'foo',
                'version' => '200',
                'sha1' => 'fake_sha1',
                'blobstore_id' => 'blobstore_id_for_foo_job',
              },
            ],
            'template' => 'foo',
            'version' => '200',
            'sha1' => 'fake_sha1',
            'blobstore_id' => 'blobstore_id_for_foo_job',
          },
        )
      end
    end
  end

  describe '#bind_unallocated_vms' do
    subject(:instance_group) { described_class.new(logger) }

    it 'allocates a VM to all non obsolete instances if they are not already bound to a VM' do
      az = BD::DeploymentPlan::AvailabilityZone.new('az', {})
      instance0 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', nil, {}, az, logger)
      instance0.bind_existing_instance_model(BD::Models::Instance.make(bootstrap: true))
      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', nil, {}, az, logger)
      instance_plan0 = BD::DeploymentPlan::InstancePlan.new({desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance), existing_instance: nil, instance: instance0})
      instance_plan1 = BD::DeploymentPlan::InstancePlan.new({desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance), existing_instance: nil, instance: instance1})
      obsolete_plan = BD::DeploymentPlan::InstancePlan.new({desired_instance: nil, existing_instance: nil, instance: instance1})

      instance_group.add_instance_plans([instance_plan0, instance_plan1, obsolete_plan])
    end
  end

  describe '#bind_instances' do
    subject(:instance_group) { described_class.new(logger) }

    it 'makes sure theres a model and binds instance networks' do
      az = BD::DeploymentPlan::AvailabilityZone.new('az', {})
      instance0 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', nil, {}, az, logger)
      instance0.bind_existing_instance_model(BD::Models::Instance.make(bootstrap: true))
      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', nil, {}, az, logger)
      instance0_reservation = BD::DesiredNetworkReservation.new_dynamic(instance0.model, network)
      instance0_obsolete_reservation = BD::DesiredNetworkReservation.new_dynamic(instance0.model, network)
      instance1_reservation = BD::DesiredNetworkReservation.new_dynamic(instance1.model, network)
      instance1_existing_reservation = BD::ExistingNetworkReservation.new(instance1.model, network, '10.0.0.1', 'manual')
      instance_plan0 = Bosh::Director::DeploymentPlan::InstancePlan.new({
          desired_instance: BD::DeploymentPlan::DesiredInstance.new,
          existing_instance: nil,
          instance: instance0,
        })
      instance_plan1 = Bosh::Director::DeploymentPlan::InstancePlan.new({
          desired_instance: BD::DeploymentPlan::DesiredInstance.new,
          existing_instance: nil,
          instance: instance1,
        })
      instance_plan0.network_plans = [
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance0_reservation),
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance0_obsolete_reservation, obsolete: true),
      ]
      instance_plan1.network_plans = [
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance1_reservation),
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance1_existing_reservation),
      ]

      obsolete_plan = Bosh::Director::DeploymentPlan::InstancePlan.new({desired_instance: nil, existing_instance: nil, instance: instance1})

      instance_group.add_instance_plans([instance_plan0, instance_plan1, obsolete_plan])

      [instance0, instance1].each do |instance|
        expect(instance).to receive(:ensure_model_bound).with(no_args).ordered
      end

      instance_group.bind_instances(fake_ip_provider)

      expect(fake_ip_provider).to have_received(:reserve).with(instance0_reservation)
      expect(fake_ip_provider).to have_received(:reserve).with(instance1_reservation)
      expect(fake_ip_provider).to_not have_received(:reserve).with(instance0_obsolete_reservation)
      expect(fake_ip_provider).to_not have_received(:reserve_existing_ips).with(instance1_existing_reservation)
    end
  end

  describe '#is_service?' do
    subject { described_class.new(logger) }

    context "when lifecycle profile is 'service'" do
      before { subject.lifecycle = 'service' }
      its(:is_service?) { should be(true) }
    end

    context 'when lifecycle profile is not service' do
      before { subject.lifecycle = 'other' }
      its(:is_service?) { should be(false) }
    end
  end

  describe '#is_errand?' do
    subject { described_class.new(logger) }

    context "when lifecycle profile is 'errand'" do
      before { subject.lifecycle = 'errand' }
      its(:is_errand?) { should be(true) }
    end

    context 'when lifecycle profile is not errand' do
      before { subject.lifecycle = 'other' }
      its(:is_errand?) { should be(false) }
    end
  end

  describe '#add_instance_plans' do
    let(:spec) do
      {
        'name' => 'foobar',
        'release' => 'appcloud',
        'instances' => 1,
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'networks'  => [{'name' => 'fake-network-name'}],
        'properties' => {},
        'template' => %w(foo bar),
      }
    end

    it 'should sort instance plans on adding them' do
      allow(plan).to receive(:properties).and_return({})
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
      expect(SecureRandom).to receive(:uuid).and_return('y-uuid-1', 'b-uuid-2', 'c-uuid-3')

      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 1, 'started', deployment, {}, nil, logger)
      instance1.bind_new_instance_model
      instance1.mark_as_bootstrap
      instance2 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 2, 'started', deployment, {}, nil, logger)
      instance2.bind_new_instance_model
      instance3 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 3, 'started', deployment, {}, nil, logger)
      instance3.bind_new_instance_model

      desired_instance = BD::DeploymentPlan::DesiredInstance.new
      instance_plan1 = BD::DeploymentPlan::InstancePlan.new(instance: instance1, existing_instance: nil, desired_instance: desired_instance)
      instance_plan2 = BD::DeploymentPlan::InstancePlan.new(instance: instance2, existing_instance: nil, desired_instance: desired_instance)
      instance_plan3 = BD::DeploymentPlan::InstancePlan.new(instance: instance3, existing_instance: nil, desired_instance: nil)

      unsorted_plans = [instance_plan3, instance_plan1, instance_plan2]
      instance_group.add_instance_plans(unsorted_plans)

      needed_instance_plans = [instance_plan1, instance_plan2]

      expect(instance_group.needed_instance_plans).to eq(needed_instance_plans)
      expect(instance_group.obsolete_instance_plans).to eq([instance_plan3])
    end
  end

  describe '#unignored_instance_plans' do

    let(:spec) do
      {
        'name' => 'foobar',
        'release' => 'appcloud',
        'instances' => 1,
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'networks'  => [{'name' => 'fake-network-name'}],
        'properties' => {},
        'template' => %w(foo bar),
      }
    end

    it 'should NOT return instance plans for ignored and detached instances' do
      allow(plan).to receive(:properties).and_return({})
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
      expect(SecureRandom).to receive(:uuid).and_return('y-uuid-1', 'b-uuid-2')

      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 1, 'started', deployment, {}, nil, logger)
      instance1.bind_new_instance_model
      instance1.mark_as_bootstrap
      instance2 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 2, 'started', deployment, {}, nil, logger)
      instance2.bind_new_instance_model

      instance2.model.update(ignore: true)

      desired_instance = BD::DeploymentPlan::DesiredInstance.new
      instance_plan1 = BD::DeploymentPlan::InstancePlan.new(instance: instance1, existing_instance: nil, desired_instance: desired_instance)
      instance_plan2 = BD::DeploymentPlan::InstancePlan.new(instance: instance2, existing_instance: nil, desired_instance: desired_instance)
      instance_group.add_instance_plans([instance_plan1, instance_plan2])

      unignored_instance_plans = [instance_plan1]
      expect(instance_group.unignored_instance_plans).to eq(unignored_instance_plans)
    end
  end

  describe '#add_job' do
    subject { described_class.new(logger) }

    context 'when job does not exist in instance group' do
      it 'adds job' do
        subject.add_job(release1_foo_job_model)
        expect(subject.jobs.count).to eq(1)

        expect(subject.jobs.first.name).to eq('foo')
        expect(subject.jobs.first.release.name).to eq('release1')
      end
    end

    context 'when job does exists in instance group' do
      it 'throws an exception' do
        subject.add_job(release1_foo_job_model)
        expect { subject.add_job(release1_foo_job_model) }.to raise_error "Colocated job '#{release1_foo_job_model.name}' is already added to the instance group '#{subject.name}'."
      end
    end
  end

  describe '#add_resolved_link' do
    subject { described_class.new(logger) }

    let(:link_spec_1) do
      {
        'deployment_name' => 'my_dep_name_1',
        'networks' => ['default_1'],
        'properties' => {
          'listen_port' => 'Kittens',
          'disorder_property' => 'foo'
        },
        'instances' => [{
                          'name'=> 'provider_1',
                          'index'=> 0,
                          'bootstrap'=> true,
                          'id'=> 'vroom',
                          'az'=> 'z1',
                          'address'=> '10.244.0.4'
                        }
        ]
      }
    end

    let(:link_spec_2) do
      {
        'deployment_name' => 'my_dep_name_2',
        'networks'=> ['default_2'],
        'properties'=> {
          'listen_port'=> 'Dogs',
          'disorder_property' => 'foo'
        },
        'instances'=> [{
                         'name'=> 'provider_2',
                         'index'=> 0,
                         'bootstrap'=> false,
                         'id'=> 'hello',
                         'az'=> 'z2',
                         'address'=> '10.244.0.5'
                       }
        ]
      }
    end

    let(:expected_resolved_links) do
      {
        'some-job-1' => {
          'my_link_name_1' => {
            'deployment_name' => 'my_dep_name_1',
            'instances'=> [{
              'name' => 'provider_1',
              'index' => 0,
              'bootstrap' => true,
              'id' => 'vroom',
              'az' => 'z1',
              'address' => '10.244.0.4'
            }],
            'networks'=> ['default_1'],
            'properties'=> {
              'disorder_property' => 'foo',
              'listen_port'=> 'Kittens',
            },

          }
        },
        'some-job-2' => {
          'my_link_name_2' => {
            'deployment_name' => 'my_dep_name_2',
            'instances' => [{
              'name' => 'provider_2',
              'index' => 0,
              'bootstrap' => false,
              'id' => 'hello',
              'az' => 'z2',
              'address' => '10.244.0.5'
            }],
            'networks'=> ['default_2'],
            'properties'=> {
              'disorder_property' => 'foo',
              'listen_port'=> 'Dogs',
            },
          }
        }
      }
    end

    it 'stores resolved links correctly' do
      subject.add_resolved_link('some-job-1','my_link_name_1', link_spec_1)
      subject.add_resolved_link('some-job-2','my_link_name_2', link_spec_2)

      expect(subject.resolved_links.to_json).to eq(expected_resolved_links.to_json)
    end

  end

  describe '#referenced_variable_sets' do
    let(:spec) do
      {
          'name' => 'foobar',
          'release' => 'appcloud',
          'instances' => 1,
          'vm_type' => 'dea',
          'stemcell' => 'dea',
          'networks'  => [{'name' => 'fake-network-name'}],
          'properties' => {},
          'template' => %w(foo bar),
      }
    end
    let(:variable_set1){ instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set2){ instance_double(Bosh::Director::Models::VariableSet) }
    let(:instance1){ instance_double(Bosh::Director::DeploymentPlan::Instance)}
    let(:instance2){ instance_double(Bosh::Director::DeploymentPlan::Instance)}
    let(:instance_plan1) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan2 ) { instance_double(BD::DeploymentPlan::InstancePlan) }

    before do
      allow(plan).to receive(:properties).and_return({})
      allow(plan).to receive(:release).with('appcloud').and_return(release1)

      allow(instance1).to receive(:desired_variable_set).and_return(variable_set1)
      allow(instance2).to receive(:desired_variable_set).and_return(variable_set2)

      allow(instance_plan1).to receive(:instance).and_return(instance1)
      allow(instance_plan2).to receive(:instance).and_return(instance2)
    end

    it 'returns a list of variable sets referenced by the needed_instance_plans' do
      expect(instance_group).to receive(:needed_instance_plans).and_return([instance_plan1,instance_plan2])
      expect(instance_group.referenced_variable_sets).to contain_exactly(variable_set1, variable_set2)
    end
  end

  describe '#bind_new_variable_set' do
    let(:spec) do
      {
        'name' => 'foobar',
        'release' => 'appcloud',
        'instances' => 1,
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'networks'  => [{'name' => 'fake-network-name'}],
        'properties' => {},
        'template' => %w(foo bar),
      }
    end
    let(:current_variable_set){ instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_1) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_2) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_3) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_4) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:instance_model_1) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_model_2) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_model_3) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_model_4) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_1){ instance_double(Bosh::Director::DeploymentPlan::Instance)}
    let(:instance_2){ instance_double(Bosh::Director::DeploymentPlan::Instance)}
    let(:instance_3){ instance_double(Bosh::Director::DeploymentPlan::Instance)}
    let(:instance_4){ instance_double(Bosh::Director::DeploymentPlan::Instance)}
    let(:instance_plan_1) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan_2 ) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan_3 ) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan_4 ) { instance_double(BD::DeploymentPlan::InstancePlan) }

    before do
      allow(plan).to receive(:properties).and_return({})
      allow(plan).to receive(:release).with('appcloud').and_return(release1)

      allow(instance_model_1).to receive(:variable_set).and_return(variable_set_model_1)
      allow(instance_model_2).to receive(:variable_set).and_return(variable_set_model_2)
      allow(instance_model_3).to receive(:variable_set).and_return(variable_set_model_3)
      allow(instance_model_4).to receive(:variable_set).and_return(variable_set_model_4)

      allow(instance_1).to receive(:model).and_return(instance_model_1)
      allow(instance_2).to receive(:model).and_return(instance_model_2)
      allow(instance_3).to receive(:model).and_return(instance_model_3)
      allow(instance_4).to receive(:model).and_return(instance_model_4)

      allow(instance_plan_1).to receive(:instance).and_return(instance_1)
      allow(instance_plan_2).to receive(:instance).and_return(instance_2)
      allow(instance_plan_3).to receive(:instance).and_return(instance_3)
      allow(instance_plan_4).to receive(:instance).and_return(instance_4)

      allow(instance_group).to receive(:obsolete_instance_plans).and_return([instance_plan_3])
    end

    it 'sets the instance object desired_variable_set to the new variable set for all unignored_instance_plans' do
      expect(instance_group).to receive(:unignored_instance_plans).and_return([instance_plan_1,instance_plan_2])

      expect(instance_1).to receive(:desired_variable_set=).with(current_variable_set)
      expect(instance_2).to receive(:desired_variable_set=).with(current_variable_set)
      expect(instance_3).to_not receive(:desired_variable_set=).with(current_variable_set)
      expect(instance_4).to_not receive(:desired_variable_set=).with(current_variable_set)

      instance_group.bind_new_variable_set(current_variable_set)
    end
  end

  describe '#default_network_name' do
    subject { described_class.new(logger) }

    before do
      subject.default_network['gateway'] = 'gateway-default-network'
      subject.default_network['dns'] = 'dns-default-network'
    end

    it 'returns the gateway network name' do
      expect(subject.default_network_name).to eq('gateway-default-network')
    end
  end
end
