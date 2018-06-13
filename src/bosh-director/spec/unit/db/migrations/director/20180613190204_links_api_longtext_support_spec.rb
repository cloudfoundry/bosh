require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180613190204_links_api_longtext_support.rb' do
    let(:db) { DBSpecHelper.db }

    let(:migration_file) { '20180613190204_links_api_longtext_support.rb' }
    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    context 'link provider metadata is very long (>255)' do
      it 'does not truncate metadata contents' do
        db[:deployments] << { name: 'fake-deployment', id: 42 }
        db[:link_providers] << {
          id: 5,
          deployment_id: 42,
          instance_group: 'baz',
          name: 'foo',
          type: 'bar',
          serial_id: 12,
        }

        metadata = 'a' * 1000

        db[:link_provider_intents] << {
          id: 7,
          link_provider_id: 5,
          original_name: 'original_name',
          type: 'foobar',
          name: 'some_name',
          metadata: metadata,
        }

        expect(db[:link_provider_intents].where(id: 7).first[:metadata]).to eq(metadata)
      end
    end

    context 'link consumer metadata is very long (>255)' do
      it 'does not truncate metadata contents' do
        db[:deployments] << { name: 'fake-deployment', id: 42 }
        db[:link_consumers] << {
          id: 5,
          deployment_id: 42,
          instance_group: 'baz',
          name: 'foo',
          type: 'bar',
          serial_id: 12,
        }

        metadata = 'a' * 1000

        db[:link_consumer_intents] << {
          id: 7,
          link_consumer_id: 5,
          original_name: 'original_name',
          type: 'foobar',
          name: 'some_name',
          metadata: metadata,
        }

        expect(db[:link_consumer_intents].where(id: 7).first[:metadata]).to eq(metadata)
      end
    end
  end
end
