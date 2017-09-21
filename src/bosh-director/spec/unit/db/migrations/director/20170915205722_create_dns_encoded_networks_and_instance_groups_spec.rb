require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'create_dns_groups' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170915205722_create_dns_encoded_networks_and_instance_groups.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)

      db[:deployments] << {
        id: 42,
        name: 'fake_deployment'
      }

      db[:deployments] << {
        id: 28,
        name: 'fake_deployment_2'
      }
    end

    it 'creates tables for instance group names and networks' do
      db[:local_dns_encoded_instance_groups] << {
        name: 'test_ig',
        deployment_id: 42
      }

      expect(db[:local_dns_encoded_instance_groups].first).to eq({
        id: 1,
        name: 'test_ig',
        deployment_id: 42
      })

      db[:local_dns_encoded_networks] << {
        id: 7,
        name: 'test_network'
      }

      expect(db[:local_dns_encoded_networks].first).to eq({
        id: 7,
        name: 'test_network'
      })
    end

    describe 'instance group encodings' do
      let(:basic_ig)                {{name: 'test_ig',    deployment_id: 42}}
      let(:ig_in_other_deployment)  {{name: 'test_ig',    deployment_id: 28}}
      let(:ig_with_other_name)      {{name: 'test_ig_2',  deployment_id: 42}}

      it 'does not allow dupes of an instance group name within a deployment' do
        db[:local_dns_encoded_instance_groups] << basic_ig
        db[:local_dns_encoded_instance_groups] << ig_in_other_deployment
        db[:local_dns_encoded_instance_groups] << ig_with_other_name

        expect {
          db[:local_dns_encoded_instance_groups] << basic_ig
        }.to raise_error Sequel::UniqueConstraintViolation
      end

      it 'enforces valid instance groups' do
        expect {
          db[:local_dns_encoded_instance_groups] << {
            name: 'test_ig',
            deployment_id: 39
          }
        }.to raise_error Sequel::ForeignKeyConstraintViolation

        expect {
          db[:local_dns_encoded_instance_groups] << {
            name: 'test_ig',
            deployment_id: nil
          }
        }.to raise_error Sequel::NotNullConstraintViolation
        expect {
          db[:local_dns_encoded_instance_groups] << {
            name: nil,
            deployment_id: 42
          }
        }.to raise_error Sequel::NotNullConstraintViolation
      end

      it 'does not prevent deployment deletion' do
        db[:local_dns_encoded_instance_groups] << basic_ig
        expect(db[:local_dns_encoded_instance_groups].where(name: 'test_ig').all.count).to eq 1
        db[:deployments].where(id: 42).delete
        expect(db[:local_dns_encoded_instance_groups].where(name: 'test_ig').all.count).to eq 0
      end
    end

    describe 'encoded networks' do
      it 'does not allow dupes' do
        db[:local_dns_encoded_networks] << {
          id: 1,
          name: 'net1'
        }

        expect {
          db[:local_dns_encoded_networks] << {
            id: 2,
            name: 'net1'
          }
        }.to raise_error Sequel::UniqueConstraintViolation

        expect {
          db[:local_dns_encoded_networks] << {
            id: 1,
            name: 'net3'
          }
        }.to raise_error Sequel::UniqueConstraintViolation

        db[:local_dns_encoded_networks] << {
          id: 2,
          name: 'net2'
        }
      end

      it 'requires a real network name' do
        expect {
          db[:local_dns_encoded_networks] << {
            id: 1,
            name: nil
          }
        }.to raise_error Sequel::NotNullConstraintViolation
      end
    end
  end
end
