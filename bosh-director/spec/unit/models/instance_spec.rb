require 'spec_helper'
require 'bosh/director/models/instance'

module Bosh::Director::Models
  describe Instance do
    subject { described_class.make(job: 'test-job') }

    describe '#cloud_properties_hash' do
      context 'when the cloud_properties are not nil' do
        it 'should return the parsed json' do
          subject.cloud_properties = '{"foo":"bar"}'
          expect(subject.cloud_properties_hash).to eq({'foo' => 'bar'})
        end
      end

      context "when the instance's cloud_properties are nil" do
        context 'when the model is missing data' do
          it 'does not error' do
            expect(subject.cloud_properties_hash).to eq({})
          end
        end

        context 'when the vm_type has cloud_properties' do
          it 'should return cloud_properties from vm_type' do
            subject.spec = {'vm_type' => {'cloud_properties' => {'foo' => 'bar'}}}
            expect(subject.cloud_properties_hash).to eq({'foo' => 'bar'})
          end
        end

        context 'when the vm_type has no cloud properties' do
          it 'does not error' do
            subject.spec = {'vm_type' => {'cloud_properties' => nil}}
            expect(subject.cloud_properties_hash).to eq({})
          end
        end
      end
    end

    describe '#latest_rendered_templates_archive' do
      def perform
        subject.latest_rendered_templates_archive
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'returns nil' do
          expect(perform).to be_nil
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        let!(:latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: subject,
            created_at: Time.new(2013, 02, 01),
          )
        end

        let!(:not_latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: subject,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'returns most recent archive for associated instance' do
          expect(perform).to eq(latest)
        end

        it 'does not account for archives for other instances' do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-non-associated-latest-blob-id',
            instance: described_class.make,
            created_at: latest.created_at + 10_000,
          )

          expect(perform).to eq(latest)
        end
      end
    end

    describe '#stale_rendered_templates_archives' do
      def perform
        subject.stale_rendered_templates_archives
      end

      context 'when instance model has no associated rendered templates archives' do
        it 'returns empty dataset' do
          expect(perform.to_a).to eq([])
        end
      end

      context 'when instance model has multiple associated rendered templates archives' do
        let!(:latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-latest-blob-id',
            instance: subject,
            created_at: Time.new(2013, 02, 01),
          )
        end

        let!(:not_latest) do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-stale-blob-id',
            instance: subject,
            created_at: Time.new(2013, 01, 01),
          )
        end

        it 'returns non-latest archives for associated instance' do
          expect(perform.to_a).to eq([not_latest])
        end

        it 'does not include archives for other instances' do
          RenderedTemplatesArchive.make(
            blobstore_id: 'fake-non-associated-latest-blob-id',
            instance: described_class.make,
            created_at: not_latest.created_at - 10_000,
          )

          expect(perform.to_a).to eq([not_latest])
        end
      end
    end

    describe '#name' do
      it 'returns the instance name' do
        expect(subject.name).to eq("test-job/#{subject.uuid}")
      end
    end

    context 'apply' do
      before do
        subject.spec=({
          'resource_pool' =>
            {'name' => 'a',
              'cloud_properties' => {},
              'stemcell' => {
                'name' => 'ubuntu-stemcell',
                'version' => '1'
              }
            }
        })
      end

      it 'should have vm_type' do
        expect(subject.spec_p('vm_type')).to eq({'name' => 'a', 'cloud_properties' => {}})
      end

      it 'should have stemcell' do
        expect(subject.spec_p('stemcell')).to eq({
              'alias' => 'a',
              'name' => 'ubuntu-stemcell',
              'version' => '1'
            })
      end
    end

    context 'spec_p' do
      it 'should return the property at the given dot separated path' do
        subject.spec=({'foo' => {'bar' => 'baz'}})
        expect(subject.spec_p('foo.bar')).to eq('baz')
      end

      context 'when the spec is nil' do
        it 'returns nil' do
          subject.spec_json = nil
          expect(subject.spec_json).to eq(nil)
          expect(subject.spec_p('foo')).to eq(nil)
          expect(subject.spec_p('foo.bar')).to eq(nil)
        end
      end

      context 'when the path does not exist' do
        it 'returns nil' do
          subject.spec=({'foo' => 'bar'})
          expect(subject.spec_p('nothing')).to eq(nil)
        end
      end

      context 'when none of the path exists' do
        it 'returns nil' do
          subject.spec=({'foo' => 'bar'})
          expect(subject.spec_p('nothing.anywhere')).to eq(nil)
        end
      end

      context 'when the path refers to a value that is not a hash' do
        it 'returns nil' do
          subject.spec=({'foo' => 'bar'})
          expect(subject.spec_p('foo.bar')).to eq(nil)
        end
      end
    end

    context 'spec' do
      it 'calls adjust_instance_spec_after_retrieval helper method after reading from DB' do
        subject.spec=({'stuff' => 'stuff'})
        expect(Bosh::Director::InstanceModelHelper).to receive(:adjust_instance_spec_after_retrieval!).with({'stuff' => 'stuff'}).and_return({})
        subject.spec
      end

      context 'when spec_json persisted in database has no resource pool' do
        it 'returns spec_json as is' do
          subject.spec=({
            'vm_type' => 'stuff',
            'stemcell' => 'stuff'
          })

          expect(subject.spec['vm_type']).to eq('stuff')
          expect(subject.spec['stemcell']).to eq('stuff')
        end
      end

      context 'when spec_json has resource pool persisted in database' do
        context 'when resource_pool has vm_type and stemcell information' do
          it 'returns vm_type and stemcell values' do
            subject.spec=({
              'resource_pool' =>
                {'name' => 'a',
                  'cloud_properties' => {},
                  'stemcell' => {
                    'name' => 'ubuntu-stemcell',
                    'version' => '1'
                  }
                }
            })

            expect(subject.spec['vm_type']).to eq(
                {'name' => 'a',
                 'cloud_properties' => {}
                }
            )

            expect(subject.spec['stemcell']).to eq(
              {'name' => 'ubuntu-stemcell',
               'version' => '1',
               'alias' => 'a'
              }
             )
          end
        end

        context 'when resource_pool DOES NOT have vm_type and stemcell information' do
          it 'returns vm_type only' do
            subject.spec=({
              'resource_pool' =>
                {'name' => 'a',
                  'cloud_properties' => {},
                }
            })
            expect(subject.spec['vm_type']).to eq(
              {'name' => 'a',
                'cloud_properties' => {}
              }
            )
          end
        end
      end
    end

    context 'spec=' do
      let(:instance_spec) do
        {
          'properties' => {'name' => 'a'},
        }
      end

      it 'calls prepare_instance_spec_for_saving helper method before saving' do
        expect(Bosh::Director::InstanceModelHelper).to receive(:prepare_instance_spec_for_saving!).with(instance_spec).and_return({})
        subject.spec=(instance_spec)
      end
    end

    context 'vm_env' do
      it 'returns env contents' do
        subject.spec=({'env' => {'a' => 'a_value'}})
        expect(subject.vm_env).to eq({'a' => 'a_value'})
      end

      it 'returns empty hash when env is nil' do
        subject.spec=({'env' => nil})
        expect(subject.vm_env).to eq({})
      end

      it 'returns empty hash when spec is nil' do
        subject.spec=(nil)
        expect(subject.vm_env).to eq({})
      end
    end

    context 'vm_uninterpolated_env' do
      it 'returns uninterpolated_env contents' do
        subject.spec=({'env' => {'a' => '((a_placeholder))'}})
        expect(subject.vm_uninterpolated_env).to eq({'a' => '((a_placeholder))'})
      end

      it 'returns empty hash when vm_uninterpolated_env is nil' do
        subject.spec=({'uninterpolated_env' => nil})
        expect(subject.vm_uninterpolated_env).to eq({})
      end

      it 'returns empty hash when spec is nil' do
        subject.spec=(nil)
        expect(subject.vm_uninterpolated_env).to eq({})
      end
    end

    context 'with deployment_plan' do
      subject { described_class.make(deployment: deployment, job: 'job-1') }

      let(:instance_groups) {
        [{
             'name' => 'job-1',
             'lifecycle' => lifecycle,
             'instances' => 1,
             'jobs' => [],
             'vm_type' => 'm1.small',
             'stemcell' => 'stemcell',
             'networks' => [{'name' => 'network'}]
         }]
      }

      let(:manifest) {
        {
            'name' => 'something',
            'releases' => [],'instance_groups' => instance_groups,
            'update' => {
                'canaries' => 1,
                'max_in_flight' => 1,
                'canary_watch_time' => 20,
                'update_watch_time' => 20
            },
            'stemcells' => [{
                                'name' => 'stemcell',
                                'alias' => 'stemcell'
                            }]
        }
      }

      let(:cloud_config_hash) {
        {
            'compilation' => {
                'network' => 'network',
                'workers' => 1
            },
            'networks' => [{
                               'name' => 'network',
                               'subnets' => []

                           }],
            'vm_types' => [{
                               'name' => 'm1.small'
                           }]

        }
      }
      let(:manifest_text) { manifest.to_yaml }
      let(:cloud_config) { CloudConfig.make(manifest: cloud_config_hash) }
      let(:deployment) { Deployment.make(name: 'deployment', manifest: manifest_text, cloud_config: cloud_config) }

      describe '#lifecycle' do
        context "when lifecycle is 'service'" do
          let(:lifecycle) { 'service' }
          it "returns 'service'" do
            expect(subject.lifecycle).to eq('service')
          end
        end

        context "when lifecycle is 'errand'" do
          let(:lifecycle) { 'errand' }
          it "returns 'errand'" do
            expect(subject.lifecycle).to eq('errand')
          end
        end

        context 'when no manifest is stored in the database' do
          let(:manifest_text) { nil }
          it "returns 'nil'" do
            expect(subject.lifecycle).to be_nil
          end
        end
      end

      describe '#expects_vm?' do

        context "when lifecycle is 'errand'" do
          let(:lifecycle) { 'errand' }

          it "doesn't expect vm" do
            expect(subject.expects_vm?).to eq(false)
          end
        end

        context "when lifecycle is 'service'" do
          let(:lifecycle) { 'service' }

          ['started', 'stopped'].each do |state|

            context "when state is '#{state}'" do
              subject { described_class.make(deployment: deployment, job: 'job-1', state: "#{state}") }

              it 'expects a vm' do
                expect(subject.expects_vm?).to eq(true)
              end
            end
          end

          context "when state is 'detached'" do
            subject { described_class.make(deployment: deployment, job: 'job-1', state: 'detached') }

            it "doesn't expect vm" do
              expect(subject.expects_vm?).to eq(false)
            end
          end

        end
      end
    end
  end
end
