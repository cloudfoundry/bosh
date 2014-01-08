require 'spec_helper'
require 'bosh/director/deployment_plan/job_spec_parser'

describe Bosh::Director::DeploymentPlan::JobSpecParser do
  subject(:parser) { described_class.new(deployment_plan) }
  let(:deployment_plan) do
    instance_double(
      'Bosh::Director::DeploymentPlan::Planner',
      model: Bosh::Director::Models::Deployment.make,
      properties: {},
      update: nil,
    )
  end

  describe '#parse' do
    before { allow(deployment_plan).to receive(:resource_pool).and_return(resource_pool) }
    let(:resource_pool) do
      instance_double(
        'Bosh::Director::DeploymentPlan::ResourcePool',
        reserve_capacity: nil,
      )
    end

    before { allow(Bosh::Director::DeploymentPlan::UpdateConfig).to receive(:new) }

    before { allow(deployment_plan).to receive(:release).and_return(job_rel_ver) }
    let(:job_rel_ver) do
      instance_double(
        'Bosh::Director::DeploymentPlan::ReleaseVersion',
        template: nil,
      )
    end

    before { allow(deployment_plan).to receive(:network).and_return(network) }
    let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network') }

    let(:job_spec) do
      {
        'name'      => 'fake-job-name',
        'templates' => [],
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
          "Job `fake-job-name' references an unknown release `unknown-release-name'",
        )
      end
    end

    describe 'template key' do
      before { job_spec.delete('templates') }

      it 'parses a single template' do
        job_spec['template'] = 'fake-template-name'

        expect(deployment_plan).to receive(:release)
          .with('fake-release-name')
          .and_return(job_rel_ver)

        template = make_template('fake-template-name', job_rel_ver)
        expect(job_rel_ver).to receive(:use_template_named)
          .with('fake-template-name')
          .and_return(template)

        job = parser.parse(job_spec)
        expect(job.templates).to eq([template])
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
        expect(job_rel_ver).to receive(:use_template_named)
          .with('fake-template1-name')
          .and_return(template1)

        template2 = make_template('fake-template2-name', job_rel_ver)
        expect(job_rel_ver).to receive(:use_template_named)
          .with('fake-template2-name')
          .and_return(template2)

        job = parser.parse(job_spec)
        expect(job.templates).to eq([template1, template2])
      end
    end

    describe 'templates key' do
      context 'when value is an array of hashes' do
        context 'when one of the hashes specifies a release' do
          before do
            job_spec['templates'] = [{
              'name' => 'fake-template-name',
              'release' => 'fake-template-release',
            }]
          end

          let(:template_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }

          context 'when job specifies a release' do
            before { job_spec['release'] = 'fake-job-release' }

            it 'sets job template from release specified in a hash' do
              expect(deployment_plan).to receive(:release)
                .with('fake-template-release')
                .and_return(template_rel_ver)

              template = make_template('fake-template-name', template_rel_ver)
              expect(template_rel_ver).to receive(:use_template_named)
                .with('fake-template-name')
                .and_return(template)

              job = parser.parse(job_spec)
              expect(job.templates).to eq([template])
            end
          end

          context 'when job does not specify a release' do
            before { job_spec.delete('release') }

            before { allow(deployment_plan).to receive(:releases).and_return([deployment_rel_ver]) }
            let(:deployment_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }

            it 'sets job template from release specified in a hash' do
              expect(deployment_plan).to receive(:release)
                .with('fake-template-release')
                .and_return(template_rel_ver)

              template = make_template('fake-template-name', nil)
              expect(template_rel_ver).to receive(:use_template_named)
                .with('fake-template-name')
                .and_return(template)

              job = parser.parse(job_spec)
              expect(job.templates).to eq([template])
            end
          end
        end

        context 'when one of the hashes does not specify a release' do
          before { job_spec['templates'] = [{'name' => 'fake-template-name'}] }

          context 'when job specifies a release' do
            before { job_spec['release'] = 'fake-job-release' }

            it 'sets job template from job release' do
              allow(deployment_plan).to receive(:release)
                .with('fake-job-release')
                .and_return(job_rel_ver)

              template = make_template('fake-template-name', nil)
              expect(job_rel_ver).to receive(:use_template_named)
                .with('fake-template-name')
                .and_return(template)

              job = parser.parse(job_spec)
              expect(job.templates).to eq([template])
            end
          end

          context 'when job does not specify a release' do
            before { job_spec.delete('release') }

            context 'when deployment has multiple releases' do
              before { allow(deployment_plan).to receive(:releases).and_return([double, double]) }

              it 'raises an error because there is not default release specified' do
                expect {
                  parser.parse(job_spec)
                }.to raise_error(
                  Bosh::Director::JobMissingRelease,
                  "Cannot tell what release job `fake-job-name' supposed to use, please reference an existing release",
                )
              end
            end

            context 'when deployment has a single release' do
              before { allow(deployment_plan).to receive(:releases).and_return([deployment_rel_ver]) }
              let(:deployment_rel_ver) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }

              it 'sets job template from deployment release because first release assumed as default' do
                template = make_template('fake-template-name', nil)
                expect(deployment_rel_ver).to receive(:use_template_named)
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
                  "Cannot tell what release job `fake-job-name' supposed to use, please reference an existing release",
                )
              end
            end
          end
        end

        context 'when one of the hashes specifies a release not specified in a deployment' do
          before do
            job_spec['templates'] = [{
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
              "Template `fake-template-name' (job `fake-job-name') references an unknown release `fake-template-release'",
            )
          end
        end

        context 'when multiple hashes have the same name' do
          before do
            job_spec['templates'] = [
              {'name' => 'fake-template-name1'},
              {'name' => 'fake-template-name2'},
              {'name' => 'fake-template-name1'},
            ]
          end

          before do # resolve release and template objs
            job_spec['release'] = 'fake-job-release'

            job_rel_ver = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')
            allow(deployment_plan).to receive(:release)
              .with('fake-job-release')
              .and_return(job_rel_ver)

            allow(job_rel_ver).to receive(:use_template_named) do |name|
              instance_double('Bosh::Director::DeploymentPlan::Template', name: name)
            end
          end

          it 'raises an error because job dirs on a VM will become ambiguous' do
            job_spec['name'] = 'fake-job-name'
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::JobInvalidTemplates,
              "Job `fake-job-name' templates must not have repeating names."
            )
          end
        end

        context 'when multiple hashes reference different releases' do
          before do
            job_spec['templates'] = [
              {'name' => 'fake-template-name1', 'release' => 'fake-template-release1'},
              {'name' => 'fake-template-name2', 'release' => 'fake-template-release2'},
            ]
          end

          before do # resolve first release and template obj
            rel_ver1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')
            allow(deployment_plan).to receive(:release)
              .with('fake-template-release1')
              .and_return(rel_ver1)

            template1 = make_template('fake-template-name1', rel_ver1)
            allow(rel_ver1).to receive(:use_template_named)
              .with('fake-template-name1')
              .and_return(template1)
          end

          before do # resolve second release and template obj
            rel_ver2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')
            allow(deployment_plan).to receive(:release)
              .with('fake-template-release2')
              .and_return(rel_ver2)

            template2 = make_template('fake-template-name2', rel_ver2)
            allow(rel_ver2).to receive(:use_template_named)
              .with('fake-template-name2')
              .and_return(template2)
          end

          it 'raises an error because currently multi-release collocation is not supported' do
            job_spec['name'] = 'fake-job-name'
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::JobInvalidTemplates,
              "Job `fake-job-name' templates must come from the same release."
            )
          end
        end

        context 'when one of the hashes is missing a name' do
          it 'raises an error because that is how template will be found' do
            job_spec['templates'] = [{}]
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::ValidationMissingField,
              %{Required property `name' was not specified in object ({})},
            )
          end
        end

        context 'when one of the elements is not a hash' do
          it 'raises an error' do
            job_spec['templates'] = ['not-a-hash']
            expect {
              parser.parse(job_spec)
            }.to raise_error(
              Bosh::Director::ValidationInvalidType,
              %{Object ("not-a-hash") did not match the required type `Hash'},
            )
          end
        end
      end

      context 'when value is not an array' do
        it 'raises an error' do
          job_spec['templates'] = 'not-an-array'
          expect {
            parser.parse(job_spec)
          }.to raise_error(
            Bosh::Director::ValidationInvalidType,
            %{Property `templates' (value "not-an-array") did not match the required type `Array'},
          )
        end
      end
    end

    describe 'validating job templates' do
      context 'when both template and templates are specified' do
        before do
          job_spec['templates'] = []
          job_spec['template'] = []
        end

        it 'raises' do
          expect { parser.parse(job_spec) }.to raise_error(
             Bosh::Director::JobInvalidTemplates,
            "Job `fake-job-name' specifies both template and templates keys, only one is allowed"
          )
        end
      end

      context 'when neither key is specified' do
        before do
          job_spec.delete('templates')
          job_spec.delete('template')
        end

        it 'raises' do
          expect { parser.parse(job_spec) }.to raise_error(
             Bosh::Director::ValidationMissingField,
             "Job `fake-job-name' does not specify template or templates keys, one is required"
          )
        end
      end
    end

    describe 'persistent_disk key' do
      it 'parses persistent disk if present' do
        job_spec['persistent_disk'] = 300
        job = parser.parse(job_spec)
        expect(job.persistent_disk).to eq(300)
      end

      it 'uses 0 for persistent disk if not present' do
        job_spec.delete('persistent_disk')
        job = parser.parse(job_spec)
        expect(job.persistent_disk).to eq(0)
      end
    end

    describe 'resource_pool key' do
      it 'parses resource pool' do
        expect(deployment_plan).to receive(:resource_pool)
          .with('fake-resource-pool-name')
          .and_return(resource_pool)

        job = parser.parse(job_spec)
        expect(job.resource_pool).to eq(resource_pool)
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
          "Job `fake-job-name' references an unknown resource pool `unknown-resource-pool'"
        )
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

    describe 'update key'
    describe 'instances key'
    describe 'networks key'

    def make_template(name, rel_ver)
      instance_double(
        'Bosh::Director::DeploymentPlan::Template',
        name: name,
        release: rel_ver,
      )
    end
  end
end
