require 'spec_helper'
require 'bosh/director/deployment_plan/job_spec_parser'

describe Bosh::Director::DeploymentPlan::JobSpecParser do
  subject(:parser) { described_class.new(deployment_plan, event_log, logger) }
  let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

  let(:deployment_plan) do
    instance_double(
      'Bosh::Director::DeploymentPlan::Planner',
      model: Bosh::Director::Models::Deployment.make,
      properties: {},
      update: nil,
      name: 'fake-deployment',
      networks: [network],
      releases: {}
    )
  end
  let(:network) { Bosh::Director::DeploymentPlan::ManualNetwork.new('fake-network-name', [], logger) }

  describe '#parse' do
    before do
      allow(deployment_plan).to receive(:resource_pool).and_return(resource_pool)
      allow(resource_pool).to receive(:name).and_return('fake-vm-type')
      allow(resource_pool).to receive(:cloud_properties).and_return({})
      allow(resource_pool).to receive(:stemcell).and_return(
          Bosh::Director::DeploymentPlan::Stemcell.parse({
              'name' => 'fake-stemcell-name',
              'version' => 1
            })
        )
    end
    let(:resource_pool_env) { {'key' => 'value'} }
    let(:resource_pool) do
      instance_double('Bosh::Director::DeploymentPlan::ResourcePool', env: resource_pool_env)
    end
    let(:disk_type) { instance_double('Bosh::Director::DeploymentPlan::DiskType') }
    before { allow(deployment_plan).to receive(:disk_type).and_return(disk_type) }

    before { allow(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new) }
    before { allow(deployment_plan).to receive(:release).and_return(job_rel_ver) }
    let(:job_rel_ver) do
      instance_double(
        'Bosh::Director::DeploymentPlan::ReleaseVersion',
        template: nil,
      )
    end

    let(:job_spec) do
      {
        'name'      => 'fake-job-name',
        'jobs' => [],
        'release'   => 'fake-release-name',
        'resource_pool' => 'fake-resource-pool-name',
        'instances' => 1,
        'networks'  => [{'name' => 'fake-network-name'}],
      }
    end

    describe 'name key' do
      it 'parses name' do
        job = parser.parse(job_spec)
        expect(job.name).to eq('fake-job-name')
      end
    end

    describe 'lifecycle key' do
      Bosh::Director::DeploymentPlan::Job::VALID_LIFECYCLE_PROFILES.each do |profile|
        it "is able to parse '#{profile}' as lifecycle profile" do
          job_spec.merge!('lifecycle' => profile)
          job = parser.parse(job_spec)
          expect(job.lifecycle).to eq(profile)
        end
      end

      it "defaults lifecycle profile to 'service'" do
        job_spec.delete('lifecycle')
        job = parser.parse(job_spec)
        expect(job.lifecycle).to eq('service')
      end

      it 'raises an error if lifecycle profile value is not known' do
        job_spec['lifecycle'] = 'unknown'

        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobInvalidLifecycle,
          "Invalid lifecycle 'unknown' for 'fake-job-name', valid lifecycle profiles are: service, errand",
        )
      end
    end

    describe 'release key' do
      it 'parses release' do
        job = parser.parse(job_spec)
        expect(job.release).to eq(job_rel_ver)
      end

      it 'complains about unknown release' do
        job_spec['release'] = 'unknown-release-name'
        expect(deployment_plan).to receive(:release)
          .with('unknown-release-name')
          .and_return(nil)

        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobUnknownRelease,
          "Instance group 'fake-job-name' references an unknown release 'unknown-release-name'",
        )
      end

      context 'when there is no job-level release defined' do
        before { job_spec.delete('release') }

        context 'when the deployment has zero releases'

        context 'when the deployment has exactly one release' do
          it "picks the deployment's release" do
            deployment_release = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: "")
            allow(deployment_plan).to receive(:releases).and_return([deployment_release])

            job = parser.parse(job_spec)
            expect(job.release).to eq(deployment_release)
          end
        end

        context 'when the deployment has more than one release' do
          it "does not pick a release" do
            job_spec.delete('release')

            allow(deployment_plan).to receive(:releases).and_return([instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: ""), instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name:"")])

            job = parser.parse(job_spec)
            expect(job.release).to be_nil
          end
        end
      end
    end

    describe 'template key' do
      before { job_spec.delete('jobs') }
      before { allow(event_log).to receive(:warn_deprecated) }

      it 'parses a single template' do
        job_spec['template'] = 'fake-template-name'

        expect(deployment_plan).to receive(:release)
          .with('fake-release-name')
          .and_return(job_rel_ver)

        template = make_template('fake-template-name', job_rel_ver)
        expect(job_rel_ver).to receive(:get_or_create_template)
          .with('fake-template-name')
          .and_return(template)

        job = parser.parse(job_spec)
        expect(job.templates).to eq([template])
      end

      it "does not issue a deprecation warning when 'template' has a single value" do
        job_spec['template'] = 'fake-template-name'

        allow(deployment_plan).to receive(:release)
                                  .with('fake-release-name')
                                  .and_return(job_rel_ver)

        template1 = make_template('fake-template-name', job_rel_ver)
        allow(job_rel_ver).to receive(:get_or_create_template)
                              .with('fake-template-name')
                              .and_return(template1)

        expect(event_log).not_to receive(:warn_deprecated)
        parser.parse(job_spec)
      end

      it 'parses multiple templates' do
        job_spec['template'] = %w(
          fake-template1-name
          fake-template2-name
        )

        expect(deployment_plan).to receive(:release)
          .with('fake-release-name')
          .and_return(job_rel_ver)

        template1 = make_template('fake-template1-name', job_rel_ver)
        expect(job_rel_ver).to receive(:get_or_create_template)
          .with('fake-template1-name')
          .and_return(template1)

        template2 = make_template('fake-template2-name', job_rel_ver)
        expect(job_rel_ver).to receive(:get_or_create_template)
          .with('fake-template2-name')
          .and_return(template2)

        job = parser.parse(job_spec)
        expect(job.templates).to eq([template1, template2])
      end

      it "issues a deprecation warning when 'template' has an array value" do
        job_spec['template'] = %w(
          fake-template1-name
          fake-template2-name
        )

        allow(deployment_plan).to receive(:release)
                                   .with('fake-release-name')
                                   .and_return(job_rel_ver)

        template1 = make_template('fake-template1-name', job_rel_ver)
        allow(job_rel_ver).to receive(:get_or_create_template)
                               .with('fake-template1-name')
                               .and_return(template1)

        template2 = make_template('fake-template2-name', job_rel_ver)
        allow(job_rel_ver).to receive(:get_or_create_template)
                               .with('fake-template2-name')
                               .and_return(template2)

        parser.parse(job_spec)
        expect(event_log).to have_received(:warn_deprecated).with(
          "Please use 'templates' when specifying multiple templates for a job. "\
          "'template' for multiple templates will soon be unsupported."
        )
      end

      it "raises an error when a job has no release" do
        job_spec['template'] = 'fake-template-name'
        job_spec.delete('release')

        fake_releases = 2.times.map {
          instance_double(
            'Bosh::Director::DeploymentPlan::ReleaseVersion',
            template: nil,
          )
        }
        expect(deployment_plan).to receive(:releases).and_return(fake_releases)

        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobMissingRelease,
          "Cannot tell what release job 'fake-job-name' is supposed to use, please explicitly specify one",
        )
      end
    end

    shared_examples_for 'templates/jobs key' do
      before { job_spec.delete('jobs') }

      context 'when value is an array of hashes' do
        context 'when one of the hashes specifies a release' do
          before do
            job_spec[keyword] = [{
              'name' => 'fake-template-name',
              'release' => 'fake-template-release',
              'consumes' => {'a' => {'from' => 'link_name'}}
            }]
            release_model = Bosh::Director::Models::Release.make(name: 'fake-release')
            version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
            release_model.add_version(version)

            fake_template_release_model = Bosh::Director::Models::Release.make(name: 'fake-template-release')
            fake_template_release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model)
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name', release: fake_template_release_model))

            deployment_model = Bosh::Director::Models::Deployment.make(name: 'deployment', link_spec_json: "{\"job_name\":{\"template_name\":{\"link_name\":{\"name\":\"link_name\",\"type\":\"link_type\"}}}}")
            version.add_deployment(deployment_model)
          end

          let(:template_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-template-release', version: '1') }

          context 'when job specifies a release' do
            before do
              job_spec['release'] = 'fake-job-release'

            end
            let(:template) { make_template('fake-template-name', template_rel_ver) }

            before do
              allow(deployment_plan).to receive(:release)
                                           .with('fake-template-release')
                                           .and_return(template_rel_ver)

              allow(template_rel_ver).to receive(:get_or_create_template)
                                            .with('fake-template-name')
                                            .and_return(template)
              allow(template).to receive(:add_link_from_manifest)
              allow(template).to receive(:add_template_scoped_properties)
            end

            it 'sets job template from release specified in a hash' do
              job = parser.parse(job_spec)
              expect(job.templates).to eq([template])
            end
          end

          context 'when job does not specify a release' do
            before { job_spec.delete('release') }

            before { allow(deployment_plan).to receive(:releases).and_return([deployment_rel_ver]) }
            let(:deployment_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: "") }
            let(:template) { make_template('fake-template-name', nil) }

            let(:provides_link) { instance_double('Bosh::Director::DeploymentPlan::Link',name: 'zz') }
            let(:provides_template) { instance_double('Bosh::Director::DeploymentPlan::Template',name: 'z') }
            let(:provides_job) { instance_double('Bosh::Director::DeploymentPlan::Job',name: 'y') }


            before do
              allow(deployment_plan).to receive(:release)
                                           .with('fake-template-release')
                                           .and_return(template_rel_ver)

              allow(provides_template).to receive(:provided_links).and_return([provides_link])
              allow(provides_job).to receive(:templates).and_return([provides_template])
              allow(deployment_plan).to receive(:jobs).and_return([provides_job])

              allow(template_rel_ver).to receive(:get_or_create_template)
                                            .with('fake-template-name')
                                            .and_return(template)
              allow(template).to receive(:add_link_from_manifest)
              allow(template).to receive(:add_template_scoped_properties)
            end

            it 'sets job template from release specified in a hash' do
              job = parser.parse(job_spec)
              expect(job.templates).to eq([template])
            end
          end
        end

        context 'when one of the hashes does not specify a release' do

          let(:job_rel_ver) do
            instance_double(
                'Bosh::Director::DeploymentPlan::ReleaseVersion',
                name: 'fake-template-release',
                version: '1',
                template: nil,
            )
          end

          before do
            job_spec[keyword] = [{'name' => 'fake-template-name', 'links' => {'db' => 'a.b.c'}}]
            fake_template_release_model = Bosh::Director::Models::Release.make(name: 'fake-template-release')
            fake_template_release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model)
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name', release: fake_template_release_model))
          end

          context 'when job specifies a release' do
            before { job_spec['release'] = 'fake-job-release' }

            it 'sets job template from job release' do
              allow(deployment_plan).to receive(:release)
                .with('fake-job-release')
                .and_return(job_rel_ver)

              template = make_template('fake-template-name', nil)
              allow(template).to receive(:add_template_scoped_properties)
              expect(job_rel_ver).to receive(:get_or_create_template)
                .with('fake-template-name')
                .and_return(template)

              job = parser.parse(job_spec)
              expect(job.templates).to eq([template])
            end
          end

          context 'when job does not specify a release' do
            before { job_spec.delete('release') }

            context 'when deployment has multiple releases' do
              before { allow(deployment_plan).to receive(:releases).and_return([deployment_rel_ver, deployment_rel_ver]) }
              let(:deployment_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: "") }

              it 'raises an error because there is not default release specified' do
                expect {
                  parser.parse(job_spec)
                }.to raise_error(
                  Bosh::Director::JobMissingRelease,
                  "Cannot tell what release template 'fake-template-name' (instance group 'fake-job-name') is supposed to use, please explicitly specify one",
                )
              end
            end

            context 'when deployment has a single release' do
              let(:deployment_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-template-release', version: '1') }
              let(:template) { make_template('fake-template-name', nil) }
              before do
                allow(deployment_plan).to receive(:releases).and_return([deployment_rel_ver])
                allow(template).to receive(:add_template_scoped_properties)
              end

              it 'sets job template from deployment release because first release assumed as default' do
                expect(deployment_rel_ver).to receive(:get_or_create_template)
                  .with('fake-template-name')
                  .and_return(template)

                job = parser.parse(job_spec)
                expect(job.templates).to eq([template])
              end
            end

            context 'when deployment has 0 releases' do
              before { allow(deployment_plan).to receive(:releases).and_return([]) }

              it 'raises an error because there is not default release specified' do
                expect {
                  parser.parse(job_spec)
                }.to raise_error(
                  Bosh::Director::JobMissingRelease,
                  "Cannot tell what release template 'fake-template-name' (instance group 'fake-job-name') is supposed to use, please explicitly specify one",
                )
              end
            end
          end
        end

        context 'when one of the hashes specifies a release not specified in a deployment' do
          before do
            job_spec[keyword] = [{
              'name' => 'fake-template-name',
              'release' => 'fake-template-release',
            }]
          end

          it 'raises an error because all referenced releases need to be specified under releases' do
            job_spec['name'] = 'fake-job-name'

            expect(deployment_plan).to receive(:release)
              .with('fake-template-release')
              .and_return(nil)

            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::JobUnknownRelease,
              "Job 'fake-template-name' (instance group 'fake-job-name') references an unknown release 'fake-template-release'",
            )
          end
        end

        context 'when multiple hashes have the same name' do
          before do
            job_spec[keyword] = [
              {'name' => 'fake-template-name1'},
              {'name' => 'fake-template-name2'},
              {'name' => 'fake-template-name1'},
            ]
          end

          before do # resolve release and template objs
            job_spec['release'] = 'fake-job-release'

            fake_template_release_model = Bosh::Director::Models::Release.make(name: 'fake-template-release')
            fake_template_release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model)
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name1', release: fake_template_release_model))
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name2', release: fake_template_release_model))
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name3', release: fake_template_release_model))

            job_rel_ver = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-template-release', version: '1')
            allow(deployment_plan).to receive(:release)
              .with('fake-job-release')
              .and_return(job_rel_ver)

            allow(job_rel_ver).to receive(:get_or_create_template) do |name|
              template = instance_double('Bosh::Director::DeploymentPlan::Template', name: name)
              allow(template).to receive(:add_template_scoped_properties)
              template
            end
          end

          it 'raises an error because job dirs on a VM will become ambiguous' do
            job_spec['name'] = 'fake-job-name'
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::JobInvalidTemplates,
              "Colocated job template 'fake-template-name1' has the same name in multiple releases. " +
              "BOSH cannot currently colocate two job templates with identical names from separate releases.",
            )
          end
        end

        context 'when multiple hashes reference different releases' do
          before do
            fake_template_release_model_1 = Bosh::Director::Models::Release.make(name: 'fake-template-release1')
            fake_template_release_version_model_1 = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model_1)
            fake_template_release_version_model_1.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name1', release: fake_template_release_model_1))

            fake_template_release_model_2 = Bosh::Director::Models::Release.make(name: 'fake-template-release2')
            fake_template_release_version_model_2 = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model_2)
            fake_template_release_version_model_2.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name2', release: fake_template_release_model_2))
          end

          it 'uses the correct release for each template' do
            job_spec[keyword] = [
              {'name' => 'fake-template-name1', 'release' => 'fake-template-release1', 'links' => {}},
              {'name' => 'fake-template-name2', 'release' => 'fake-template-release2', 'links' => {}},
            ]

            # resolve first release and template obj
            rel_ver1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-template-release1', version: '1')
            allow(deployment_plan).to receive(:release)
                                      .with('fake-template-release1')
                                      .and_return(rel_ver1)

            template1 = make_template('fake-template-name1', rel_ver1)
            allow(template1).to receive(:add_template_scoped_properties)

            expect(rel_ver1).to receive(:get_or_create_template)
                               .with('fake-template-name1')
                               .and_return(template1)

            # resolve second release and template obj
            rel_ver2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-template-release2', version: '1')
            allow(deployment_plan).to receive(:release)
                                      .with('fake-template-release2')
                                      .and_return(rel_ver2)

            template2 = make_template('fake-template-name2', rel_ver2)
            allow(template2).to receive(:add_template_scoped_properties)

            expect(rel_ver2).to receive(:get_or_create_template)
                               .with('fake-template-name2')
                               .and_return(template2)

            job_spec['name'] = 'fake-job-name'
            parser.parse(job_spec)
          end
        end

        context 'when one of the hashes is missing a name' do
          it 'raises an error because that is how template will be found' do
            job_spec[keyword] = [{}]
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::ValidationMissingField,
              "Required property 'name' was not specified in object ({})",
            )
          end
        end

        context 'when one of the elements is not a hash' do
          it 'raises an error' do
            job_spec[keyword] = ['not-a-hash']
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::ValidationInvalidType,
              %{Object ("not-a-hash") did not match the required type 'Hash'},
            )
          end
        end

        context 'when properties are provided in a template' do
          let(:job_rel_ver) do
            instance_double(
                'Bosh::Director::DeploymentPlan::ReleaseVersion',
                name: 'fake-template-release',
                version: '1',
                template: nil,
            )
          end

          before do
            job_spec['templates'] = [
                {'name' => 'fake-template-name',
                 'links' => {'db' => 'a.b.c'},
                 'properties' => {
                     'property_1' => 'property_1_value',
                     'property_2' => {
                         'life' => 'isInteresting'
                     }
                 }
                }
            ]
            job_spec['release'] = 'fake-job-release'

            fake_template_release_model = Bosh::Director::Models::Release.make(name: 'fake-template-release')
            fake_template_release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model)
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name', release: fake_template_release_model))
          end

          it 'assigns those properties to the intended template' do
            allow(deployment_plan).to receive(:release)
                                          .with('fake-job-release')
                                          .and_return(job_rel_ver)

            template = make_template('fake-template-name', nil)
            allow(job_rel_ver).to receive(:get_or_create_template)
                                      .with('fake-template-name')
                                      .and_return(template)
            expect(template).to receive(:add_template_scoped_properties)
                                    .with({"property_1"=>"property_1_value", "property_2"=>{'life' => 'isInteresting'}}, 'fake-job-name')

            parser.parse(job_spec)
          end
        end

        context 'when consumes_json and provides_json in template model have value "null"' do
          let(:job_rel_ver) do
            instance_double(
                'Bosh::Director::DeploymentPlan::ReleaseVersion',
                name: 'fake-template-release',
                version: '1',
                template: nil,
            )
          end

          before do
            job_spec['templates'] = [
                {'name' => 'fake-template-name',
                 'links' => {'db' => 'a.b.c'},
                 'properties' => {
                     'property_1' => 'property_1_value',
                     'property_2' => {
                         'life' => 'isInteresting'
                     }
                 }
                }
            ]
            job_spec['release'] = 'fake-job-release'

            fake_template_release_model = Bosh::Director::Models::Release.make(name: 'fake-template-release')
            fake_template_release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '1', release: fake_template_release_model)
            fake_template_release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'fake-template-name', release: fake_template_release_model, consumes_json: "null", provides_json: "null"))
          end

          it "does not throw an error" do
            allow(deployment_plan).to receive(:release)
                                          .with('fake-job-release')
                                          .and_return(job_rel_ver)

            template = make_template('fake-template-name', nil)
            allow(job_rel_ver).to receive(:get_or_create_template)
                                      .with('fake-template-name')
                                      .and_return(template)
            allow(template).to receive(:add_template_scoped_properties)
                                    .with({"property_1"=>"property_1_value", "property_2"=>{'life' => 'isInteresting'}}, 'fake-job-name')

            parser.parse(job_spec)
          end
        end
      end

      context 'when value is not an array' do
        it 'raises an error' do
          job_spec[keyword] = 'not-an-array'
          expect {
            parser.parse(job_spec)
          }.to raise_error(
            Bosh::Director::ValidationInvalidType,
            %{Property '#{keyword}' value ("not-an-array") did not match the required type 'Array'},
          )
        end
      end
    end

    describe 'templates key' do
      let(:keyword) { "templates" }
      it_behaves_like "templates/jobs key"
    end

    describe 'jobs key' do
      let(:keyword) { "jobs" }
      it_behaves_like "templates/jobs key"
    end

    describe 'validating job templates' do
      context 'when both template and templates are specified' do
        before do
          job_spec['templates'] = []
          job_spec['template'] = []
        end
        before { allow(event_log).to receive(:warn_deprecated) }

        it 'raises' do
          expect { parser.parse(job_spec) }.to raise_error(
             Bosh::Director::JobInvalidTemplates,
            "Instance group 'fake-job-name' specifies both template and templates keys, only one is allowed"
          )
        end
      end

      context 'when both jobs and templates are specified' do
        before do
          job_spec['templates'] = []
          job_spec['jobs'] = []
        end
        before { allow(event_log).to receive(:warn_deprecated) }

        it 'raises' do
          expect { parser.parse(job_spec) }.to raise_error(
                                                   Bosh::Director::JobInvalidTemplates,
                                                   "Instance group 'fake-job-name' specifies both templates and jobs keys, only one is allowed"
                                               )
        end
      end

      context 'when neither key is specified' do
        before do
          job_spec.delete('templates')
          job_spec.delete('template')
          job_spec.delete('jobs')
        end

        it 'raises' do
          expect { parser.parse(job_spec) }.to raise_error(
             Bosh::Director::ValidationMissingField,
             "Instance group 'fake-job-name' does not specify template, templates, or jobs keys, one is required"
          )
        end
      end
    end

    describe 'persistent_disk key' do
      it 'parses persistent disk if present' do
        job_spec['persistent_disk'] = 300
        job = parser.parse(job_spec)
        expect(job.persistent_disk_type.disk_size).to eq(300)
      end

      it 'allows persistent disk to be nil' do
        job_spec.delete('persistent_disk')
        job = parser.parse(job_spec)
        expect(job.persistent_disk_type).to eq(nil)
      end

      it 'raises an error if the disk size is less than zero' do
        job_spec['persistent_disk'] = -300
        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobInvalidPersistentDisk,
          "Instance group 'fake-job-name' references an invalid persistent disk size '-300'"
        )
      end
    end

    describe 'persistent_disk_type key' do
      it 'parses persistent_disk_type' do
        job_spec['persistent_disk_type'] = 'fake-disk-pool-name'
        expect(deployment_plan).to receive(:disk_type)
          .with('fake-disk-pool-name')
          .and_return(disk_type)

        job = parser.parse(job_spec)
        expect(job.persistent_disk_type).to eq(disk_type)
      end

      it 'complains about unknown disk type' do
        job_spec['persistent_disk_type'] = 'unknown-disk-pool'
        expect(deployment_plan).to receive(:disk_type)
          .with('unknown-disk-pool')
          .and_return(nil)

        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobUnknownDiskType,
          "Instance group 'fake-job-name' references an unknown disk type 'unknown-disk-pool'"
        )
      end
    end

    describe 'persistent_disk_pool key' do
      it 'parses persistent_disk_pool' do
        job_spec['persistent_disk_pool'] = 'fake-disk-pool-name'
        expect(deployment_plan).to receive(:disk_type)
                                     .with('fake-disk-pool-name')
                                     .and_return(disk_type)

        job = parser.parse(job_spec)
        expect(job.persistent_disk_type).to eq(disk_type)
      end

      it 'complains about unknown disk pool' do
        job_spec['persistent_disk_pool'] = 'unknown-disk-pool'
        expect(deployment_plan).to receive(:disk_type)
                                     .with('unknown-disk-pool')
                                     .and_return(nil)

        expect {
          parser.parse(job_spec)
        }.to raise_error(
            Bosh::Director::JobUnknownDiskType,
            "Instance group 'fake-job-name' references an unknown disk pool 'unknown-disk-pool'"
          )
      end
    end

    context 'when job has multiple persistent_disks keys' do
      it 'raises an error if persistent_disk and persistent_disk_pool are both present' do
        job_spec['persistent_disk'] = 300
        job_spec['persistent_disk_pool'] = 'fake-disk-pool-name'

        expect {
          parser.parse(job_spec)
        }.to raise_error(
            Bosh::Director::JobInvalidPersistentDisk,
            "Instance group 'fake-job-name' references both a persistent disk size '300' and a persistent disk pool 'fake-disk-pool-name'"
          )
      end
      it 'raises an error if persistent_disk and persistent_disk_type are both present' do
        job_spec['persistent_disk'] = 300
        job_spec['persistent_disk_type'] = 'fake-disk-pool-name'

        expect {
          parser.parse(job_spec)
        }.to raise_error(
            Bosh::Director::JobInvalidPersistentDisk,
            "Instance group 'fake-job-name' references both a persistent disk size '300' and a persistent disk type 'fake-disk-pool-name'"
          )
      end
      it 'raises an error if persistent_disk_type and persistent_disk_pool are both present' do
        job_spec['persistent_disk_type'] = 'fake-disk-pool-name'
        job_spec['persistent_disk_pool'] = 'fake-disk-pool-name'

        expect {
          parser.parse(job_spec)
        }.to raise_error(
            Bosh::Director::JobInvalidPersistentDisk,
            "Instance group 'fake-job-name' specifies both 'disk_types' and 'disk_pools', only one key is allowed. " +
              "'disk_pools' key will be DEPRECATED in the future."
          )
      end
    end

    describe 'resource_pool key' do
      it 'parses resource pool' do
        expect(deployment_plan).to receive(:resource_pool)
          .with('fake-resource-pool-name')
          .and_return(resource_pool)

        job = parser.parse(job_spec)
        expect(job.vm_type.name).to eq('fake-vm-type')
        expect(job.vm_type.cloud_properties).to eq({})
        expect(job.stemcell.name).to eq('fake-stemcell-name')
        expect(job.stemcell.version).to eq('1')
        expect(job.env.spec).to eq({'key' => 'value'})
      end

      context 'when env is also declared in the job spec' do
        before do
          job_spec['env'] = {'env1' => 'something'}
          expect(deployment_plan).to receive(:resource_pool)
           .with('fake-resource-pool-name')
           .and_return(resource_pool)
        end

        it 'complains' do
          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::JobAmbiguousEnv,
              "Instance group 'fake-job-name' and resource pool: 'fake-resource-pool-name' both declare env properties"
            )
        end
      end

      context 'when the job declares env, and the resource pool does not' do
        let(:resource_pool_env) { {} }
        before do
          job_spec['env'] = {'job' => 'env'}
          expect(deployment_plan).to receive(:resource_pool)
                                       .with('fake-resource-pool-name')
                                       .and_return(resource_pool)
        end

        it 'should assign the job env to the job' do
          job = parser.parse(job_spec)
          expect(job.env.spec).to eq({'job' => 'env'})
        end
      end

      it 'complains about unknown resource pool' do
        job_spec['resource_pool'] = 'unknown-resource-pool'
        expect(deployment_plan).to receive(:resource_pool)
          .with('unknown-resource-pool')
          .and_return(nil)

        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobUnknownResourcePool,
          "Instance group 'fake-job-name' references an unknown resource pool 'unknown-resource-pool'"
        )
      end
    end

    describe 'vm type and stemcell key' do
      before do
        allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(
            Bosh::Director::DeploymentPlan::VmType.new({
                'name' => 'fake-vm-type',
                'cloud_properties' => {}
              })
          )
        allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
            Bosh::Director::DeploymentPlan::Stemcell.parse({
                'alias' => 'fake-stemcell',
                'os' => 'fake-os',
                'version' => 1
              })
          )
      end

      let(:job_spec) do
        {
          'name'      => 'fake-job-name',
          'templates' => [],
          'release'   => 'fake-release-name',
          'vm_type' => 'fake-vm-type',
          'stemcell' => 'fake-stemcell',
          'env' => {'key' => 'value'},
          'instances' => 1,
          'networks'  => [{'name' => 'fake-network-name'}]
        }
      end

      it 'parses vm type and stemcell' do
        job = parser.parse(job_spec)
        expect(job.vm_type.name).to eq('fake-vm-type')
        expect(job.vm_type.cloud_properties).to eq({})
        expect(job.stemcell.alias).to eq('fake-stemcell')
        expect(job.stemcell.version).to eq('1')
        expect(job.env.spec).to eq({'key' => 'value'})
      end

      context 'vm type cannot be found' do
        before do
          allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(nil)
        end

        it 'errors out' do
          expect{parser.parse(job_spec)}.to raise_error(
              Bosh::Director::JobUnknownVmType,
              "Instance group 'fake-job-name' references an unknown vm type 'fake-vm-type'"
            )
        end
      end

      context 'stemcell cannot be found' do
        before do
          allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(nil)
        end

        it 'errors out' do
          expect{parser.parse(job_spec)}.to raise_error(
              Bosh::Director::JobUnknownStemcell,
              "Instance group 'fake-job-name' references an unknown stemcell 'fake-stemcell'"
            )
        end
      end

    end

    describe 'vm_extensions key' do

      let(:vm_extension_1) do
        {
            'name'             => 'vm_extension_1',
            'cloud_properties' => {'property' => 'value'}
        }
      end

      let(:vm_extension_2) do
        {
            'name'             => 'vm_extension_2',
            'cloud_properties' => {'another_property' => 'value1', 'property' => 'value2'}
        }
      end

      let(:job_spec) do
        {
            'name'      => 'fake-job-name',
            'templates' => [],
            'release'   => 'fake-release-name',
            'vm_type' => 'fake-vm-type',
            'stemcell' => 'fake-stemcell',
            'env' => {'key' => 'value'},
            'instances' => 1,
            'networks'  => [{'name' => 'fake-network-name'}]
        }
      end

      before do
        allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(
            Bosh::Director::DeploymentPlan::VmType.new({
                                                           'name' => 'fake-vm-type',
                                                           'cloud_properties' => {}
                                                       })
        )
        allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
            Bosh::Director::DeploymentPlan::Stemcell.parse({
                                                               'alias' => 'fake-stemcell',
                                                               'os' => 'fake-os',
                                                               'version' => 1
                                                           })
        )
        allow(deployment_plan).to receive(:vm_extension).with('vm_extension_1').and_return(
            Bosh::Director::DeploymentPlan::VmExtension.new(vm_extension_1)
        )
        allow(deployment_plan).to receive(:vm_extension).with('vm_extension_2').and_return(
            Bosh::Director::DeploymentPlan::VmExtension.new(vm_extension_2)
        )
      end

      context 'job has one vm_extension' do
        it 'parses the vm_extension' do
          job_spec['vm_extensions'] = ['vm_extension_1']

          job = parser.parse(job_spec)
          expect(job.vm_extensions.size).to eq(1)
          expect(job.vm_extensions.first.name).to eq('vm_extension_1')
          expect(job.vm_extensions.first.cloud_properties).to eq({'property' => 'value'})

        end
      end
    end

    describe 'properties key' do
      it 'complains about unsatisfiable property mappings' do
        props = { 'foo' => 'bar' }

        job_spec['properties'] = props
        job_spec['property_mappings'] = { 'db' => 'ccdb' }

        allow(deployment_plan).to receive(:properties).and_return(props)

        expect {
          parser.parse(job_spec)
        }.to raise_error(
          Bosh::Director::JobInvalidPropertyMapping,
        )
      end
    end

    describe 'instances key' do
      it 'parses out desired instances' do
        job = parser.parse(job_spec)

        expect(job.desired_instances).to eq([
              Bosh::Director::DeploymentPlan::DesiredInstance.new(job, deployment_plan),
            ])
      end
    end

    describe 'networks key' do
      before { job_spec['networks'].first['static_ips'] = '10.0.0.2 - 10.0.0.4' } # 2,3,4

      context 'when the number of static ips is less than number of instances' do
        it 'raises an exception because if a job uses static ips all instances must have a static ip' do
          job_spec['instances'] = 4
          expect {
            parser.parse(job_spec)
          }.to raise_error(
            Bosh::Director::JobNetworkInstanceIpMismatch,
            "Instance group 'fake-job-name' has 4 instances but was allocated 3 static IPs",
          )
        end
      end

      context 'when the number of static ips is greater the number of instances' do
        it 'raises an exception because the extra ip is wasted' do
          job_spec['instances'] = 2
          expect {
            parser.parse(job_spec)
          }.to raise_error(
            Bosh::Director::JobNetworkInstanceIpMismatch,
            "Instance group 'fake-job-name' has 2 instances but was allocated 3 static IPs",
          )
        end
      end

      context 'when number of static ips matches the number of instances' do
        it 'does not raise an exception' do
          job_spec['instances'] = 3
          expect { parser.parse(job_spec) }.to_not raise_error
        end
      end

      context 'when there are multiple networks specified as default for a property' do
        it 'errors' do
          job_spec['instances'] = 3
          job_spec['networks'].first['default'] = ['gateway', 'dns']
          job_spec['networks'] << job_spec['networks'].first.merge('name' => 'duped-network') # dupe it
          duped_network = Bosh::Director::DeploymentPlan::ManualNetwork.new('duped-network', [], logger)
          allow(deployment_plan).to receive(:networks).and_return([duped_network, network])

          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::JobNetworkMultipleDefaults,
              "Instance group 'fake-job-name' specified more than one network to contain default. " +
                "'dns' has default networks: 'fake-network-name', 'duped-network'. "+
                "'gateway' has default networks: 'fake-network-name', 'duped-network'."
            )
        end
      end

      context 'when there are no networks specified as default for a property' do
        context 'when there is only one network' do
          it 'picks the only network as default' do
            job_spec['instances'] = 3
            allow(deployment_plan).to receive(:networks).and_return([network])
            parsed_job = parser.parse(job_spec)

            expect(parsed_job.default_network['dns']).to eq('fake-network-name')
            expect(parsed_job.default_network['gateway']).to eq('fake-network-name')
          end
        end

        context 'when there are two networks, each being a separate default' do
          let(:network2) { Bosh::Director::DeploymentPlan::ManualNetwork.new('fake-network-name-2', [], logger) }

          it 'picks the only network as default' do
            job_spec['networks'].first['default'] = ['dns']
            job_spec['networks'] << { 'name' => 'fake-network-name-2', 'default' => [ 'gateway' ] }
            job_spec['instances'] = 3
            allow(deployment_plan).to receive(:networks).and_return([network, network2])
            parsed_job = parser.parse(job_spec)

            expect(parsed_job.default_network['dns']).to eq('fake-network-name')
            expect(parsed_job.default_network['gateway']).to eq('fake-network-name-2')
          end
        end

      end
    end

    describe 'azs key' do
      context 'when there is a key but empty values' do
        it 'raises an exception' do
          job_spec['azs'] = []

          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::JobMissingAvailabilityZones, "Instance group 'fake-job-name' has empty availability zones"
            )
        end
      end

      context 'when there is a key with values' do
        it 'parses each value into the AZ on the deployment' do
          zone1, zone2 = set_up_azs!(["zone1", "zone2"], job_spec, deployment_plan)
          allow(network).to receive(:has_azs?).and_return(true)
          expect(parser.parse(job_spec).availability_zones).to eq([zone1, zone2])
        end

        it 'raises an exception if the value are not strings' do
          job_spec['azs'] = ['valid_zone', 3]
          allow(network).to receive(:has_azs?).and_return(true)
          allow(deployment_plan).to receive(:availability_zone).with("valid_zone") { instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone) }

          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::JobInvalidAvailabilityZone, "Instance group 'fake-job-name' has invalid availability zone '3', string expected"
            )
        end

        it 'raises an exception if the referenced AZ doesnt exist in the deployment' do
          job_spec['azs'] = ['existent_zone', 'nonexistent_zone']
          allow(network).to receive(:has_azs?).and_return(true)
          allow(deployment_plan).to receive(:availability_zone).with("existent_zone") { instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone) }
          allow(deployment_plan).to receive(:availability_zone).with("nonexistent_zone") { nil }

          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::JobUnknownAvailabilityZone, "Instance group 'fake-job-name' references unknown availability zone 'nonexistent_zone'"
            )
        end

        it 'raises an error if the referenced AZ is not specified on networks' do
          allow(network).to receive(:has_azs?).and_return(false)

          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::JobNetworkMissingRequiredAvailabilityZone,
                "Instance group 'fake-job-name' must specify availability zone that matches availability zones of network 'fake-network-name'"
            )
        end

        describe 'validating AZs against the networks of the job' do
          it 'validates that every network satisfies job AZ requirements' do
            set_up_azs!(['zone1', 'zone2'], job_spec, deployment_plan)
            job_spec['networks'] = [
              {'name' => 'first-network'},
              {'name' => 'second-network', 'default' => ['dns', 'gateway']}
            ]

            first_network = instance_double(
              Bosh::Director::DeploymentPlan::ManualNetwork,
              name: 'first-network',
              has_azs?: true,
              validate_reference_from_job!: true
            )
            second_network = instance_double(
              Bosh::Director::DeploymentPlan::ManualNetwork,
              name: 'second-network',
              has_azs?: true,
              validate_reference_from_job!: true
            )
            allow(deployment_plan).to receive(:networks).and_return([first_network, second_network])

            parser.parse(job_spec)

            expect(first_network).to have_received(:has_azs?).with(['zone1', 'zone2'])
            expect(second_network).to have_received(:has_azs?).with(['zone1', 'zone2'])
          end
        end
      end

      context 'when there is a key with the wrong type' do
        it 'an exception is raised' do
          job_spec['azs'] = 3

          expect {
            parser.parse(job_spec)
          }.to raise_error(
              Bosh::Director::ValidationInvalidType, "Property 'azs' value (3) did not match the required type 'Array'"
            )
        end
      end
    end

    describe 'migrated_from' do
      let(:job_spec) do
        {
          'name'      => 'fake-job-name',
          'templates' => [],
          'release'   => 'fake-release-name',
          'resource_pool' => 'fake-resource-pool-name',
          'instances' => 1,
          'networks'  => [{'name' => 'fake-network-name'}],
          'migrated_from' => [{'name' => 'job-1', 'az' => 'z1'}, {'name' => 'job-2', 'az' => 'z2'}],
          'azs' => ['z1', 'z2']
        }
      end
      before do
        allow(network).to receive(:has_azs?).and_return(true)
        allow(deployment_plan).to receive(:availability_zone).with('z1') { Bosh::Director::DeploymentPlan::AvailabilityZone.new('z1', {}) }
        allow(deployment_plan).to receive(:availability_zone).with('z2') { Bosh::Director::DeploymentPlan::AvailabilityZone.new('z2', {}) }
      end

      it 'sets migrated_from on a job' do
        job = parser.parse(job_spec)
        expect(job.migrated_from[0].name).to eq('job-1')
        expect(job.migrated_from[0].availability_zone).to eq('z1')
        expect(job.migrated_from[1].name).to eq('job-2')
        expect(job.migrated_from[1].availability_zone).to eq('z2')
      end

      context 'when az is specified' do
        context 'when migrated job refers to az that is not in the list of availaibility_zones key' do
          it 'raises an error' do
            job_spec['migrated_from'] = [{'name' => 'job-1', 'az' => 'unknown_az'}]

            expect {
              parser.parse(job_spec)
            }.to raise_error(
                Bosh::Director::DeploymentInvalidMigratedFromJob,
                "Instance group 'job-1' specified for migration to instance group 'fake-job-name' refers to availability zone 'unknown_az'. " +
                  "Az 'unknown_az' is not in the list of availability zones of instance group 'fake-job-name'."
              )
          end
        end
      end
    end

    describe 'remove_dev_tools' do
      let(:resource_pool_env) { {} }
      before { allow(Bosh::Director::Config).to receive(:remove_dev_tools).and_return(false) }

      it 'does not add remove_dev_tools by default' do
        job = parser.parse(job_spec)
        expect(job.env.spec['bosh']).to eq(nil)
      end

      it 'does what the job env says' do
        job_spec['env'] = {'bosh' => {'remove_dev_tools' => 'custom'}}
        job = parser.parse(job_spec)
        expect(job.env.spec['bosh']['remove_dev_tools']).to eq('custom')
      end

      describe 'when director manifest specifies director.remove_dev_tools' do
        before { allow(Bosh::Director::Config).to receive(:remove_dev_tools).and_return(true) }

        it 'should do what director wants' do
          job = parser.parse(job_spec)
          expect(job.env.spec['bosh']['remove_dev_tools']).to eq(true)
        end
      end

      describe 'when both the job and director specify' do
        before do
          allow(Bosh::Director::Config).to receive(:remove_dev_tools).and_return(true)
          job_spec['env'] = {'bosh' => {'remove_dev_tools' => false}}
        end

        it 'defers to the job' do
          job = parser.parse(job_spec)
          expect(job.env.spec['bosh']['remove_dev_tools']).to eq(false)
        end
      end
    end

    def set_up_azs!(azs, job_spec, deployment_plan)
      job_spec['azs'] = azs
      azs.map do |az_name|
        fake_az = instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: az_name)
        allow(deployment_plan).to receive(:availability_zone).with(az_name) { fake_az }
        fake_az
      end
    end

    def make_template(name, rel_ver)
      instance_double(
        'Bosh::Director::DeploymentPlan::Template',
        name: name,
        release: rel_ver,
        link_infos: {}
      )
    end
  end
end
