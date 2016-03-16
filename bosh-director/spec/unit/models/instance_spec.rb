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
        expect(subject.spec['vm_type']).to eq({'name' => 'a', 'cloud_properties' => {}})
      end

      it 'should have stemcell' do
        expect(subject.spec['stemcell']).to eq({
              'alias' => 'a',
              'name' => 'ubuntu-stemcell',
              'version' => '1'
            })
      end
    end

    context 'spec' do
      context 'when spec_json persisted in database has no resource pool' do
        it 'returns spec_json as is' do
          subject.spec=({
            'vm_type' => 'stuff',
            'stemcell' => 'stuff'
          })

          expect(subject.spec).to eq({'vm_type' => 'stuff', 'stemcell' => 'stuff'})
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
            expect(subject.spec).to eq(
                {
                  'vm_type' =>
                    {'name' => 'a',
                      'cloud_properties' => {}
                    },
                  'stemcell' =>
                    {'name' => 'ubuntu-stemcell',
                      'version' => '1',
                      'alias' => 'a'
                    }
                })
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
            expect(subject.spec).to eq(
                {
                  'vm_type' =>
                    {'name' => 'a',
                      'cloud_properties' => {}
                    }
                }
              )
          end
        end
      end
    end
  end
end
