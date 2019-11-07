require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstanceGroup do
  let(:instance_group) { Bosh::Director::DeploymentPlan::InstanceGroup.parse(plan, spec, event_log, logger, parse_options) }
  let(:parse_options) { {} }
  let(:event_log)  { instance_double('Bosh::Director::EventLog::Log', warn_deprecated: nil) }
  let(:deployment) { Bosh::Director::Models::Deployment.make }
  let(:fake_ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProvider, reserve: nil, reserve_existing_ips: nil) }
  let(:vm_type) { Bosh::Director::DeploymentPlan::VmType.new('name' => 'dea') }
  let(:stemcell) do
    model = Bosh::Director::Models::Stemcell.make(name: 'linux', version: '250.4')
    new_stemcell = Bosh::Director::DeploymentPlan::Stemcell.make(
      name: model.name,
      os: 'linux',
      version: model.version,
    )
    new_stemcell.add_stemcell_models
    new_stemcell
  end
  let(:env) { instance_double('Bosh::Director::DeploymentPlan::Env') }
  let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

  let(:plan) do
    instance_double(
      'Bosh::Director::DeploymentPlan::Planner',
      model: deployment,
      name: deployment.name,
      ip_provider: fake_ip_provider,
      release: release1,
      use_tmpfs_config: false,
      networks: [network],
      vm_type: vm_type,
      stemcell: stemcell,
      links_manager: links_manager,
      update: nil,
      properties: {},
    )
  end

  let(:spec) do
    {
      'name' => 'foobar',
      'release' => release1.name,
      'jobs' => [
        {
          'name' => release1_foo_job.name,
          'release' => release1.name,
        },
      ],
      'vm_type' => 'dea',
      'stemcell' => 'dea',
      'env' => { 'key' => 'value' },
      'instances' => 1,
      'networks' => [{ 'name' => 'fake-network-name' }],
    }
  end

  let(:network) do
    instance_double(
      'Bosh::Director::DeploymentPlan::Network',
      name: 'fake-network-name',
      validate_reference_from_job!: true,
      has_azs?: true,
    )
  end

  let(:foo_properties) do
    {
      'dea_min_memory' => { 'default' => 512 },
      'deep_property.dont_override' => { 'default' => 'ghi' },
      'deep_property.new_property' => { 'default' => 'jkl' },
    }
  end

  let(:bar_properties) do
    { 'dea_max_memory' => { 'default' => 2048 } }
  end

  let(:release1_foo_job) do
    r = Bosh::Director::DeploymentPlan::Job.new(release1, 'foo')
    r.bind_existing_model(release1_foo_job_model)
    r
  end
  let(:release1_foo_job_model) { Bosh::Director::Models::Template.make(name: 'foo', release: release1_model) }

  let(:release1_bar_job) do
    r = Bosh::Director::DeploymentPlan::Job.new(release1, 'bar')
    r.bind_existing_model(release1_bar_job_model)
    r
  end
  let(:release1_bar_job_model) { Bosh::Director::Models::Template.make(name: 'bar', release: release1_model) }

  let(:release1_package1_model) do
    Bosh::Director::Models::Package.make(name: 'same-name', release: release1_model, fingerprint: 'abc123')
  end

  let(:release1_package1_model2) do
    Bosh::Director::Models::Package.make(name: 'same-name', release: release1_model, fingerprint: 'c68y74')
  end

  let(:release1) do
    Bosh::Director::DeploymentPlan::ReleaseVersion.parse(
      deployment,
      'name' => 'release1',
      'version' => '1',
    )
  end

  let(:release1_model) { Bosh::Director::Models::Release.make(name: 'release1') }
  let(:release1_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '1', release: release1_model) }
  let(:release1_version2_model) { Bosh::Director::Models::ReleaseVersion.make(version: '2', release: release1_model) }
  let(:update_config) { double(Bosh::Director::DeploymentPlan::UpdateConfig) }
  let(:links_serial_id) { 7 }

  let(:links_manager) { Bosh::Director::Links::LinksManager.new(links_serial_id, logger, event_log) }

  before do
    allow(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new).and_return update_config

    allow(release1).to receive(:get_or_create_template).with('foo').and_return(release1_foo_job)
    allow(release1).to receive(:get_or_create_template).with('bar').and_return(release1_bar_job)
    allow(release1).to receive(:model).and_return(release1_model)

    allow(release1_foo_job).to receive(:properties)
    allow(release1_bar_job).to receive(:properties)

    allow(release1_foo_job).to receive(:add_properties)
    allow(release1_bar_job).to receive(:add_properties)
    allow(deployment).to receive(:current_variable_set).and_return(Bosh::Director::Models::VariableSet.make)

    release1_version_model.add_template(release1_foo_job_model)
    release1_version_model.add_template(release1_bar_job_model)

    release1_version2_model.add_template(release1_foo_job_model)
    release1_version2_model.add_template(release1_bar_job_model)

    release1_version_model.add_package(release1_package1_model)
    release1_version2_model.add_package(release1_package1_model2)
  end

  describe '#parse' do
    let(:spec) do
      {
        'name' => 'foobar',
        'release' => 'appcloud',
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'env' => { 'key' => 'value' },
        'instances' => 1,
        'networks' => [{ 'name' => 'fake-network-name' }],
        'jobs' => [],
        'update' => update,
      }
    end

    before do
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
    end

    context 'when parse_options contain canaries' do
      let(:parse_options) do
        { 'canaries' => 42 }
      end
      let(:update) do
        { 'canaries' => 22 }
      end

      it 'overrides canaries value with one from parse_options' do
        expect(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)
          .with(parse_options, nil)
        instance_group
      end
    end

    context 'when parse_options contain max_in_flight' do
      let(:parse_options) do
        { 'max_in_flight' => 42 }
      end
      let(:update) do
        { 'max_in_flight' => 22 }
      end

      it 'overrides max_in_flight value with one from parse_options' do
        expect(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new)
          .with(parse_options, nil)
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
        'env' => { 'key' => 'value' },
        'instances' => 1,
        'networks' => [
          { 'name' => 'fake-network-name', 'default' => %w[dns gateway] },
          { 'name' => 'fake-network-name2' },
        ],
        'jobs' => [
          { 'name' => 'foo', 'release' => 'appcloud' },
          { 'name' => 'bar', 'release' => 'appcloud' },
        ],
      }
    end

    let(:foo_properties) do
      {
        'foobar' => {
          'cc_url' => 'www.cc.com',
          'deep_property' => {
            'unneeded' => 'abc',
            'dont_override' => 'def',
          },
        },
      }
    end

    let(:bar_properties) do
      {
        'foobar' => {
          'vroom' => 'smurf',
          'dea_max_memory' => 1024,
        },
      }
    end

    let(:options) do
      {
        dns_record_names: [
          "*.foobar.fake-network-name.#{deployment.name}.bosh",
          "*.foobar.fake-network-name2.#{deployment.name}.bosh",
        ],
      }
    end

    let(:network2) do
      instance_double(
        'Bosh::Director::DeploymentPlan::Network',
        name: 'fake-network-name2',
        validate_reference_from_job!: true,
        has_azs?: true,
      )
    end

    before do
      allow(plan).to receive(:networks).and_return([network, network2])
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
      allow(release1_foo_job).to receive(:properties).and_return(foo_properties)
      allow(release1_bar_job).to receive(:properties).and_return(bar_properties)
    end

    it 'binds all job properties with correct parameters' do
      expect(release1_foo_job).to receive(:bind_properties).with('foobar')
      expect(release1_bar_job).to receive(:bind_properties).with('foobar')

      instance_group.bind_properties

      expect(instance_group.properties).to eq(
        'foo' => {
          'cc_url' => 'www.cc.com',
          'deep_property' => {
            'unneeded' => 'abc',
            'dont_override' => 'def',
          },
        },
        'bar' => {
          'vroom' => 'smurf',
          'dea_max_memory' => 1024,
        },
      )
    end
  end

  describe '#validate_package_names_do_not_collide!' do
    before do
      allow(plan).to receive(:release).with('release1').and_return(release1)
    end

    context 'when the templates are from the same release' do
      let(:spec) do
        {
          'name' => 'foobar',
          'jobs' => [
            { 'name' => 'foo', 'release' => 'release1' },
            { 'name' => 'bar', 'release' => 'release1' },
          ],
          'vm_type' => 'dea',
          'stemcell' => 'dea',
          'env' => { 'key' => 'value' },
          'instances' => 1,
          'networks' => [{ 'name' => 'fake-network-name' }],
        }
      end

      context 'when jobs depend on packages with the same name (i.e. same package)' do
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

    context 'when the jobs are from different releases' do
      let(:release2) do
        Bosh::Director::DeploymentPlan::ReleaseVersion.parse(deployment,
                                                             'name' => 'release2',
                                                             'version' => '1')
      end
      let(:release2_foo_job) do
        r = Bosh::Director::DeploymentPlan::Job.new(release2, 'foo')
        r.bind_existing_model(release2_foo_job_model)
        r
      end
      let(:release2_bar_job) do
        r = Bosh::Director::DeploymentPlan::Job.new(release2, 'bar')
        r.bind_existing_model(release2_bar_job_model)
        r
      end
      let(:release2_foo_job_model) { Bosh::Director::Models::Template.make(name: 'foo', release: release2_model) }
      let(:release2_bar_job_model) { Bosh::Director::Models::Template.make(name: 'bar', release: release2_model) }
      let(:release2_model) { Bosh::Director::Models::Release.make(name: 'release2') }
      let(:release2_version_model) { Bosh::Director::Models::ReleaseVersion.make(release: release2_model, version: 1) }
      let(:release2_version2_model) { Bosh::Director::Models::ReleaseVersion.make(release: release2_model, version: 2) }
      let(:release2_package1_model) do
        Bosh::Director::Models::Package.make(
          name: release2_package1_name,
          release: release2_model,
          fingerprint: release2_package1_fingerprint,
          dependency_set_json: JSON.dump(release2_package1_dependencies),
        )
      end
      let(:release2_package1_model2) do
        Bosh::Director::Models::Package.make(
          name: release2_package1_name,
          release: release2_model,
          fingerprint: release2_package1_fingerprint2,
          dependency_set_json: JSON.dump(release2_package1_dependencies),
        )
      end
      let(:release2_package1_fingerprint) { '987asd' }
      let(:release2_package1_fingerprint2) { 'c68y74' }
      let(:release2_package1_name) { 'another-name' }
      let(:release2_package1_dependencies) { [] }

      before do
        release2_version_model.add_template(release2_foo_job_model)
        release2_version_model.add_template(release2_bar_job_model)

        release2_version2_model.add_template(release2_foo_job_model)
        release2_version2_model.add_template(release2_bar_job_model)

        release2_version_model.add_package(release2_package1_model)
        release2_version2_model.add_package(release2_package1_model2)

        release1_foo_job_model.package_names = [release1_package1_model.name, release1_package1_model2.name]
        release1_foo_job_model.save
        release2_bar_job_model.package_names = [release2_package1_model.name, release2_package1_model2.name]
        release2_bar_job_model.save

        allow(plan).to receive(:releases).with(no_args).and_return([release1, release2])
        allow(plan).to receive(:release).with('release1').and_return(release1)
        allow(plan).to receive(:release).with('release2').and_return(release2)

        allow(release2).to receive(:get_or_create_template).with('foo').and_return(release2_foo_job)
        allow(release2).to receive(:get_or_create_template).with('bar').and_return(release2_bar_job)
        allow(release2).to receive(:model).and_return(release2_model)
      end

      let(:spec) do
        {
          'name' => 'foobar',
          'jobs' => [
            { 'name' => 'foo', 'release' => 'release1' },
            { 'name' => 'bar', 'release' => 'release2', 'links' => { 'a' => 'x.y.z.zz' } },
          ],
          'vm_type' => 'dea',
          'stemcell' => 'dea',
          'env' => { 'key' => 'value' },
          'instances' => 1,
          'networks' => [{ 'name' => 'fake-network-name' }],
        }
      end

      context 'when jobs do not depend on packages with the same name' do
        before do
          link_provider = instance_double(Bosh::Director::Models::Links::LinkProvider)
          allow(links_manager).to receive(:find_or_create_provider).and_return(link_provider)
        end

        it 'does not raise an exception' do
          expect { instance_group.validate_package_names_do_not_collide! }.to_not raise_error
        end
      end

      context 'when jobs depend on packages with the same name' do
        let(:release2_package1_name) { 'same-name' }

        context 'fingerprints are different' do
          let(:release2_package1_fingerprint) { '987asd' }

          it 'raises an exception because agent currently cannot collocate similarly named packages from multiple releases' do
            expect do
              instance_group.validate_package_names_do_not_collide!
            end.to raise_error(
              Bosh::Director::JobPackageCollision,
              "Package name collision detected in instance group 'foobar': "\
              "job 'release1/foo' depends on package 'release1/same-name' with fingerprint 'abc123',"\
              " job 'release2/bar' depends on package 'release2/same-name' with fingerprint '987asd'. "\
              'BOSH cannot currently collocate two packages with identical names and different fingerprints or dependencies.',
            )
          end
        end

        context 'fingerprints are the same' do
          let(:release2_package1_fingerprint) { 'abc123' }

          context 'when dependencies are the same' do
            it 'does not raise an exception' do
              expect { instance_group.validate_package_names_do_not_collide! }.to_not raise_error
            end
          end

          context 'when dependencies are not the same' do
            let(:release2_package1_dependencies) { ['whatever'] }

            it 'raises an exception' do
              expect do
                instance_group.validate_package_names_do_not_collide!
              end.to raise_error(
                Bosh::Director::JobPackageCollision,
                "Package name collision detected in instance group 'foobar': "\
                "job 'release1/foo' depends on package 'release1/same-name' with fingerprint 'abc123',"\
                " job 'release2/bar' depends on package 'release2/same-name' with fingerprint 'abc123'. "\
                'BOSH cannot currently collocate two packages with identical names and different fingerprints or dependencies.',
              )
            end
          end
        end
      end
    end
  end

  describe '#validate_exported_from_matches_stemcell!' do
    context 'when jobs have no exported_from' do
      it 'does not raise an error' do
        expect do
          instance_group.validate_exported_from_matches_stemcell!
        end.to_not raise_error
      end
    end

    context 'when jobs have exported_from that matches the stemcell' do
      let(:release1) do
        Bosh::Director::DeploymentPlan::ReleaseVersion.parse(
          deployment,
          'name' => 'release1',
          'version' => '1',
          'exported_from' => [{
            'os' => stemcell.os,
            'version' => stemcell.version,
          }],
        )
      end

      it 'does not raise an error' do
        expect do
          instance_group.validate_exported_from_matches_stemcell!
        end.to_not raise_error
      end
    end

    context 'when jobs have exported_from that do not match the stemcell' do
      let(:release1) do
        Bosh::Director::DeploymentPlan::ReleaseVersion.parse(
          deployment,
          'name' => 'release1',
          'version' => '1',
          'exported_from' => [{
            'os' => 'the wrong one',
            'version' => '3',
          }],
        )
      end

      it 'raises an error' do
        expect do
          instance_group.validate_exported_from_matches_stemcell!
        end.to raise_error(
          Bosh::Director::JobWithExportedFromMismatch,
          "Invalid release detected in instance group 'foobar' using stemcell '#{stemcell.desc}': "\
          "release 'release1' must be exported from stemcell 'linux/250.4'. "\
          "Release 'release1' is exported from: 'the wrong one/3'.",
        )
      end
    end

    context 'when there are multiple exported_from for a release' do
      context 'and at least one of them matches the stemcell' do
        let(:release1) do
          Bosh::Director::DeploymentPlan::ReleaseVersion.parse(
            deployment,
            'name' => 'release1',
            'version' => '1',
            'exported_from' => [
              {
                'os' => 'ubuntu-trusty',
                'version' => '3143',
              },
              {
                'os' => stemcell.os,
                'version' => stemcell.version,
              },
            ],
          )
        end

        it 'does not raise an error' do
          instance_group.validate_exported_from_matches_stemcell!
        end
      end

      context 'and none of them matches the stemcell' do
        let(:release1) do
          Bosh::Director::DeploymentPlan::ReleaseVersion.parse(
            deployment,
            'name' => 'release1',
            'version' => '1',
            'exported_from' => [
              {
                'os' => 'the wrong one',
                'version' => '3',
              },
              {
                'os' => 'the wrong two',
                'version' => '12',
              },
            ],
          )
        end

        it 'raises an error' do
          expect do
            instance_group.validate_exported_from_matches_stemcell!
          end.to raise_error(
            Bosh::Director::JobWithExportedFromMismatch,
            "Invalid release detected in instance group 'foobar' using stemcell 'linux/250.4': "\
            "release 'release1' must be exported from stemcell 'linux/250.4'. "\
            "Release 'release1' is exported from: 'the wrong one/3', 'the wrong two/12'.",
          )
        end
      end
    end
  end

  describe '#spec' do
    let(:spec) do
      {
        'name' => 'job1',
        'jobs' => [{ 'name' => 'foo', 'release' => 'release1' }],
        'release' => 'release1',
        'instances' => 1,
        'vm_type' => 'dea',
        'stemcell' => 'dea',
        'env' => { 'key' => 'value' },
        'networks' => [{ 'name' => 'fake-network-name' }],
      }
    end

    before do
      allow(release1_foo_job).to receive(:version).and_return('200')
      allow(release1_foo_job).to receive(:sha1).and_return('fake_sha1')
      allow(release1_foo_job).to receive(:blobstore_id).and_return('blobstore_id_for_foo_job')
      allow(release1_foo_job).to receive(:properties).and_return({})

      allow(plan).to receive(:releases).with(no_args).and_return([release1])
      allow(plan).to receive(:release).with('release1').and_return(release1)
    end

    context "when a job has 'logs'" do
      before do
        allow(release1_foo_job).to receive(:logs).and_return(
          'filter_name1' => 'foo/*',
        )
      end

      it 'contains name, release for the job, and logs spec for each job' do
        expect(instance_group.spec).to eq(
          'name' => 'job1',
          'template' => 'foo',
          'version' => '200',
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
        )
      end
    end

    context "when a template does not have 'logs'" do
      before do
        allow(release1_foo_job).to receive(:logs)
      end

      it 'contains name, release and information for each template' do
        expect(instance_group.spec).to eq(
          'name' => 'job1',
          'template' => 'foo',
          'version' => '200',
          'templates' => [
            {
              'name' => 'foo',
              'version' => '200',
              'sha1' => 'fake_sha1',
              'blobstore_id' => 'blobstore_id_for_foo_job',
            },
          ],
        )
      end
    end
  end

  describe '#bind_unallocated_vms' do
    it 'allocates a VM to all non obsolete instances if they are not already bound to a VM' do
      az = BD::DeploymentPlan::AvailabilityZone.new('az', {})
      instance0 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', deployment, {}, az, logger, variables_interpolator)
      instance0.bind_existing_instance_model(BD::Models::Instance.make(bootstrap: true))
      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', deployment, {}, az, logger, variables_interpolator)
      instance_plan0 = BD::DeploymentPlan::InstancePlan.new(
        desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance),
        existing_instance: nil,
        instance: instance0,
        variables_interpolator: variables_interpolator,
      )
      instance_plan1 = BD::DeploymentPlan::InstancePlan.new(
        desired_instance: instance_double(Bosh::Director::DeploymentPlan::DesiredInstance),
        existing_instance: nil,
        instance: instance1,
        variables_interpolator: variables_interpolator,
      )
      obsolete_plan = BD::DeploymentPlan::InstancePlan.new(desired_instance: nil, existing_instance: nil, instance: instance1, variables_interpolator: variables_interpolator)

      instance_group.add_instance_plans([instance_plan0, instance_plan1, obsolete_plan])
    end
  end

  describe '#bind_instances' do
    it 'makes sure theres a model and binds instance networks' do
      az = BD::DeploymentPlan::AvailabilityZone.new('az', {})
      instance0 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', deployment, {}, az, logger, variables_interpolator)
      instance0.bind_existing_instance_model(BD::Models::Instance.make(bootstrap: true))
      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(instance_group, 6, 'started', deployment, {}, az, logger, variables_interpolator)
      instance0_reservation = BD::DesiredNetworkReservation.new_dynamic(instance0.model, network)
      instance0_obsolete_reservation = BD::DesiredNetworkReservation.new_dynamic(instance0.model, network)
      instance1_reservation = BD::DesiredNetworkReservation.new_dynamic(instance1.model, network)
      instance1_existing_reservation = BD::ExistingNetworkReservation.new(instance1.model, network, '10.0.0.1', 'manual')
      instance_plan0 = Bosh::Director::DeploymentPlan::InstancePlan.new(
        desired_instance: BD::DeploymentPlan::DesiredInstance.new,
        existing_instance: nil,
        instance: instance0,
        variables_interpolator: variables_interpolator,
      )
      instance_plan1 = Bosh::Director::DeploymentPlan::InstancePlan.new(
        desired_instance: BD::DeploymentPlan::DesiredInstance.new,
        existing_instance: nil,
        instance: instance1,
        variables_interpolator: variables_interpolator,
      )
      instance_plan0.network_plans = [
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance0_reservation),
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance0_obsolete_reservation, obsolete: true),
      ]
      instance_plan1.network_plans = [
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance1_reservation),
        BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: instance1_existing_reservation),
      ]

      obsolete_plan = Bosh::Director::DeploymentPlan::InstancePlan.new(
        desired_instance: nil,
        existing_instance: nil,
        instance: instance1,
        variables_interpolator: variables_interpolator,
      )

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

  describe '#service?' do
    context "when lifecycle profile is 'service'" do
      before { spec['lifecycle'] = 'service' }
      it 'returns true if it is a service' do
        expect(instance_group.service?).to eq(true)
      end
    end

    context 'when lifecycle profile is not valid' do
      before { spec['lifecycle'] = 'other' }
      it 'returns an error' do
        expect { instance_group }.to raise_error(
          Bosh::Director::JobInvalidLifecycle,
          "Invalid lifecycle 'other' for 'foobar', valid lifecycle profiles are: service, errand",
        )
      end
    end
  end

  describe '#errand?' do
    context "when lifecycle profile is 'errand'" do
      before { spec['lifecycle'] = 'errand' }
      it 'returns true if it is an errand' do
        expect(instance_group.errand?).to eq(true)
      end
    end

    context 'when lifecycle profile is not errand' do
      before { spec['lifecycle'] = 'service' }
      it 'returns false if it is not an errand' do
        expect(instance_group.errand?).to eq(false)
      end
    end
  end

  describe '#create_swap_delete?' do
    context 'when vm_strategy is create-swap-delete' do
      before do
        allow(update_config).to receive(:vm_strategy).and_return 'create-swap-delete'
      end

      it 'returns true' do
        expect(instance_group.create_swap_delete?).to eq true
      end
    end

    context 'when vm_strategy is not create-swap-delete' do
      before do
        allow(update_config).to receive(:vm_strategy).and_return 'something-else'
      end

      it 'returns false' do
        expect(instance_group.create_swap_delete?).to eq false
      end
    end
  end

  describe '#should_create_swap_delete?' do
    context 'when vm_strategy is create-swap-delete' do
      before do
        allow(update_config).to receive(:vm_strategy).and_return 'create-swap-delete'
      end

      context 'when instance_group does not have static ips' do
        before do
          spec['networks'] = [
            {
              'name' => network.name,
              'static_ips' => nil,
            },
          ]
        end

        it 'returns true' do
          expect(instance_group.should_create_swap_delete?).to eq true
        end
      end

      context 'when instance_group has static ips' do
        before do
          spec['networks'] = [
            {
              'name' => network.name,
              'static_ips' => ['1.1.1.1'],
            },
          ]
        end

        it 'returns false' do
          expect(instance_group.should_create_swap_delete?).to eq false
        end
      end
    end

    context 'when vm_strategy is not create-swap-delete' do
      before do
        allow(update_config).to receive(:vm_strategy).and_return 'something-else'
      end

      it 'returns false' do
        expect(instance_group.should_create_swap_delete?).to eq false
      end
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
        'networks' => [{ 'name' => 'fake-network-name' }],
        'jobs' => [],
      }
    end

    it 'should sort instance plans on adding them' do
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
      expect(SecureRandom).to receive(:uuid).and_return('y-uuid-1', 'b-uuid-2', 'c-uuid-3')

      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        1,
        'started',
        deployment,
        {},
        nil,
        logger,
        variables_interpolator,
      )
      instance1.bind_new_instance_model
      instance1.mark_as_bootstrap
      instance2 = BD::DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        2,
        'started',
        deployment,
        {},
        nil,
        logger,
        variables_interpolator,
      )
      instance2.bind_new_instance_model
      instance3 = BD::DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        3,
        'started',
        deployment,
        {},
        nil,
        logger,
        variables_interpolator,
      )
      instance3.bind_new_instance_model

      desired_instance = BD::DeploymentPlan::DesiredInstance.new
      instance_plan1 = BD::DeploymentPlan::InstancePlan.new(
        instance: instance1,
        existing_instance: nil,
        desired_instance: desired_instance,
        variables_interpolator: variables_interpolator,
      )
      instance_plan2 = BD::DeploymentPlan::InstancePlan.new(
        instance: instance2,
        existing_instance: nil,
        desired_instance: desired_instance,
        variables_interpolator: variables_interpolator,
      )
      instance_plan3 = BD::DeploymentPlan::InstancePlan.new(
        instance: instance3,
        existing_instance: nil,
        desired_instance: nil,
        variables_interpolator: variables_interpolator,
      )

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
        'networks' => [{ 'name' => 'fake-network-name' }],
        'jobs' => [],
      }
    end

    it 'should NOT return instance plans for ignored and detached instances' do
      allow(plan).to receive(:release).with('appcloud').and_return(release1)
      expect(SecureRandom).to receive(:uuid).and_return('y-uuid-1', 'b-uuid-2')

      instance1 = BD::DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        1,
        'started',
        deployment,
        {},
        nil,
        logger,
        variables_interpolator,
      )
      instance1.bind_new_instance_model
      instance1.mark_as_bootstrap
      instance2 = BD::DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        2,
        'started',
        deployment,
        {},
        nil,
        logger,
        variables_interpolator,
      )
      instance2.bind_new_instance_model

      instance2.model.update(ignore: true)

      desired_instance = BD::DeploymentPlan::DesiredInstance.new
      instance_plan1 = BD::DeploymentPlan::InstancePlan.new(
        instance: instance1,
        existing_instance: nil,
        desired_instance: desired_instance,
        variables_interpolator: variables_interpolator,
      )
      instance_plan2 = BD::DeploymentPlan::InstancePlan.new(
        instance: instance2,
        existing_instance: nil,
        desired_instance: desired_instance,
        variables_interpolator: variables_interpolator,
      )
      instance_group.add_instance_plans([instance_plan1, instance_plan2])

      unignored_instance_plans = [instance_plan1]
      expect(instance_group.unignored_instance_plans).to eq(unignored_instance_plans)
    end
  end

  describe '#add_job' do
    before do
      spec['jobs'] = []
    end

    context 'when job does not exist in instance group' do
      it 'adds job' do
        instance_group.add_job(release1_foo_job_model)
        expect(instance_group.jobs.count).to eq(1)

        expect(instance_group.jobs.first.name).to eq('foo')
        expect(instance_group.jobs.first.release.name).to eq('release1')
      end
    end

    context 'when job does exists in instance group' do
      it 'throws an exception' do
        instance_group.add_job(release1_foo_job_model)
        expect { instance_group.add_job(release1_foo_job_model) }.to raise_error(
          "Colocated job '#{release1_foo_job_model.name}' is already added "\
          "to the instance group '#{instance_group.name}'.",
        )
      end
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
        'networks' => [{ 'name' => 'fake-network-name' }],
        'jobs' => [],
      }
    end
    let(:variable_set1) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set2) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:instance1) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
    let(:instance2) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
    let(:instance_plan1) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan2) { instance_double(BD::DeploymentPlan::InstancePlan) }

    before do
      allow(plan).to receive(:release).with('appcloud').and_return(release1)

      allow(instance1).to receive(:desired_variable_set).and_return(variable_set1)
      allow(instance2).to receive(:desired_variable_set).and_return(variable_set2)

      allow(instance_plan1).to receive(:instance).and_return(instance1)
      allow(instance_plan2).to receive(:instance).and_return(instance2)
    end

    it 'returns a list of variable sets referenced by the needed_instance_plans' do
      expect(instance_group).to receive(:needed_instance_plans).and_return([instance_plan1, instance_plan2])
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
        'networks' => [{ 'name' => 'fake-network-name' }],
        'jobs' => [],
      }
    end
    let(:current_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_1) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_2) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_3) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:variable_set_model_4) { instance_double(Bosh::Director::Models::VariableSet) }
    let(:instance_model_1) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_model_2) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_model_3) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_model_4) { instance_double(Bosh::Director::Models::Instance) }
    let(:instance_1) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
    let(:instance_2) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
    let(:instance_3) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
    let(:instance_4) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
    let(:instance_plan_1) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan_2) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan_3) { instance_double(BD::DeploymentPlan::InstancePlan) }
    let(:instance_plan_4) { instance_double(BD::DeploymentPlan::InstancePlan) }

    before do
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
      expect(instance_group).to receive(:unignored_instance_plans).and_return([instance_plan_1, instance_plan_2])

      expect(instance_1).to receive(:desired_variable_set=).with(current_variable_set)
      expect(instance_2).to receive(:desired_variable_set=).with(current_variable_set)
      expect(instance_3).to_not receive(:desired_variable_set=).with(current_variable_set)
      expect(instance_4).to_not receive(:desired_variable_set=).with(current_variable_set)

      instance_group.bind_new_variable_set(current_variable_set)
    end
  end

  describe '#default_network_name' do
    before do
      instance_group.default_network['gateway'] = 'gateway-default-network'
      instance_group.default_network['dns'] = 'dns-default-network'
    end

    it 'returns the gateway network name' do
      expect(instance_group.default_network_name).to eq('gateway-default-network')
    end

    context 'when addressable is specified' do
      before do
        instance_group.default_network['addressable'] = 'something'
      end

      it 'returns the addressable network' do
        expect(instance_group.default_network_name).to eq('something')
      end
    end
  end

  describe '#unignored_instance_plans_needing_duplicate_vm' do
    let(:instance_plan_instance) { instance_double(BD::DeploymentPlan::Instance, vm_created?: true, state: 'started') }
    let(:instance_plan) do
      instance_double(BD::DeploymentPlan::InstancePlan, instance: instance_plan_instance, new?: false, needs_duplicate_vm?: true, should_be_ignored?: false)
    end
    let(:instance_plan_sorter) { instance_double(BD::DeploymentPlan::InstancePlanSorter, sort: [instance_plan]) }

    before do
      allow(BD::DeploymentPlan::InstancePlanSorter).to receive(:new).and_return(instance_plan_sorter)
    end

    context 'when the plan has a created instance and needs shutting down' do
      it 'selects the instance plan' do
        expect(instance_group.unignored_instance_plans_needing_duplicate_vm).to eq([instance_plan])
      end
    end

    context 'when instance group contains detached instance plan' do
      before do
        allow(instance_plan_instance).to receive(:state).and_return('detached')
      end

      it 'should filter detached instance plans' do
        expect(instance_group.unignored_instance_plans_needing_duplicate_vm).to be_empty
      end
    end

    context 'when the instance plan should be ignored' do
      before do
        allow(instance_plan).to receive(:should_be_ignored?).and_return(true)
      end

      it 'should not be considered for hot swap' do
        expect(instance_group.unignored_instance_plans_needing_duplicate_vm).to be_empty
      end
    end

    context 'when a new instance is added to a deployment' do
      before do
        allow(instance_plan).to receive(:new?).and_return(true)
      end

      it 'should not be considered for hot swap' do
        expect(instance_group.unignored_instance_plans_needing_duplicate_vm).to be_empty
      end
    end

    context 'when the instance does not need shutting down' do
      before do
        allow(instance_plan).to receive(:needs_duplicate_vm?).and_return(false)
      end

      it 'should not be considered for hot swap' do
        expect(instance_group.unignored_instance_plans_needing_duplicate_vm).to be_empty
      end
    end
  end

  describe 'use_compiled_package' do
    let(:compiled_package) { Bosh::Director::Models::CompiledPackage.make(package: release1_package1_model) }
    let(:registered_release_job_model) { Bosh::Director::Models::Template.make(name: 'bar', release: release1_model) }
    let(:deployment_plan_job) { Bosh::Director::DeploymentPlan::Job.new(release1, 'foo') }
    let(:new_compiled_package) { Bosh::Director::Models::CompiledPackage.make(package: release1_package1_model) }

    before(:each) do
      spec['jobs'] = []

      allow(registered_release_job_model).to receive(:package_names).and_return(['same-name'])
      allow(release1).to receive(:get_template_model_by_name).with('foo').and_return registered_release_job_model
      allow(release1).to receive(:get_package_model_by_name).with('same-name').and_return release1_package1_model
      deployment_plan_job.bind_models
      instance_group.add_job(deployment_plan_job)
    end

    context 'when the fingerprint is the same' do
      it 'adds the package to the instance groups packages by name' do
        instance_group.use_compiled_package(compiled_package)
        expect(instance_group.packages[compiled_package.name].model).to equal(compiled_package)
      end

      context 'when the package is already registered' do
        before do
          instance_group.use_compiled_package(compiled_package)
        end

        it 'replaces the package if the package id is greater than the registered package, but not if the package ID is less' do
          instance_group.use_compiled_package(new_compiled_package)
          expect(instance_group.package_spec).to eq(
            'same-name' => BD::DeploymentPlan::CompiledPackage.new(new_compiled_package).spec,
          )

          instance_group.use_compiled_package(compiled_package)
          expect(instance_group.package_spec).to eq(
            'same-name' => BD::DeploymentPlan::CompiledPackage.new(new_compiled_package).spec,
          )
        end
      end

      context 'when the new package is only compile-time dependency' do
        let(:release1_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '1', release: release1_model) }
        let(:compile_time_package) { Bosh::Director::Models::Package.make(name: 'same-name', fingerprint: 'b') }
        let(:compiled_package_model) { Bosh::Director::Models::CompiledPackage.make(package: compile_time_package) }

        before do
          instance_group.use_compiled_package(compiled_package)
        end

        it 'does not override the existing package' do
          instance_group.use_compiled_package(compiled_package_model)
          expect(instance_group.package_spec).to eq(
            'same-name' => BD::DeploymentPlan::CompiledPackage.new(compiled_package).spec,
          )
        end
      end
    end
  end
end
