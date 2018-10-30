require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20181017210108_add_type_to_local_dns_encoded_instance_group.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'has a unique index on type, name, and deployment_id' do
      DBSpecHelper.migrate(subject)
      db[:deployments] << {
        id: 1,
        name: 'foo',
      }
      db[:local_dns_encoded_instance_groups] << {
        type: 'foo-type',
        name: 'foo-name',
        deployment_id: 1,
      }
      expect do
        db[:local_dns_encoded_instance_groups] << {
          type: 'foo-type',
          name: 'foo-name',
          deployment_id: 1,
        }
      end.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'updates existing records to type instance-group' do
      db[:deployments] << {
        id: 1,
        name: 'foo',
      }
      db[:local_dns_encoded_instance_groups] << {
        name: 'foo-name',
        deployment_id: 1,
      }
      db[:local_dns_encoded_instance_groups] << {
        name: 'foo-name-2',
        deployment_id: 1,
      }

      DBSpecHelper.migrate(subject)

      db[:local_dns_encoded_instance_groups].all.each do |rec|
        expect(rec[:type]).to eq('instance-group')
      end
    end

    it 'defaults type to instance-group' do
      DBSpecHelper.migrate(subject)
      db[:deployments] << {
        id: 1,
        name: 'foo',
      }

      db[:local_dns_encoded_instance_groups] << {
        name: 'foo-name',
        deployment_id: 1,
      }
      expect(db[:local_dns_encoded_instance_groups].first[:type]).to eq 'instance-group'
    end
  end
end
