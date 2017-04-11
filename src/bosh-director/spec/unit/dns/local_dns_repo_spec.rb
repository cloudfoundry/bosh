require 'spec_helper'

module Bosh::Director
  describe LocalDnsRepo do
    subject(:local_dns_repo) { LocalDnsRepo.new(logger) }
    let(:deployment_model) { Models::Deployment.make(name: 'bosh.1') }

    let(:instance_model) do
      Models::Instance.make(
          uuid: 'uuid',
          index: 1,
          deployment: deployment_model,
          job: 'instance-group-0',
          availability_zone: 'az1',
          spec_json: JSON.dump(spec_json),
      )
    end

    let(:spec_json) { {'networks' => {'net-name' => {'ip' => '1234'}}} }

    let(:record_0_ip) { '1234' }
    let!(:local_dns_record_0) do
      Models::LocalDnsRecord.create(
          :ip => record_0_ip,
          :instance => instance_model,
          :az => 'az1',
          :network => 'net-name',
          :deployment => 'bosh.1',
          :instance_group => 'instance-group-0'
      )
    end

    context 'update for instance' do
      context 'when a matching record already exists' do
        it 'does not change the records' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to_not change { Models::LocalDnsRecord.max(:id) }
          expect(Models::LocalDnsRecord.all).to eq([local_dns_record_0])
        end

        it 'does not have changes on the diff' do
          diff = local_dns_repo.diff(instance_model)
          expect(diff.changes?).to be(false)
        end
      end

      context 'when an instance has a different ip address' do
        let(:record_0_ip) { '5678' }

        it 'inserts a new record' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)

          records = Models::LocalDnsRecord.all
          expect(records.size).to eq(1)

          local_dns_record = records.first
          expect(local_dns_record.ip).to eq('1234')
          expect(local_dns_record.az).to eq('az1')
          expect(local_dns_record.network).to eq('net-name')
          expect(local_dns_record.deployment).to eq('bosh.1')
          expect(local_dns_record.instance_group).to eq('instance-group-0')
          expect(local_dns_record.instance).to eq(instance_model)
        end

        it 'will compute the difference between the instance model and the existing local dns records' do
          diff = local_dns_repo.diff(instance_model)
          expect(diff.changes?).to be(true)
          expect(diff.obsolete).to eq([{
            :ip => '5678',
            :instance_id => instance_model.id,
            :az => 'az1',
            :network => 'net-name',
            :deployment => 'bosh.1',
            :instance_group => 'instance-group-0',
          }])
          expect(diff.missing).to eq([{
            :ip => '1234',
            :instance_id => instance_model.id,
            :az => 'az1',
            :network => 'net-name',
            :deployment => 'bosh.1',
            :instance_group => 'instance-group-0',
          }])
          expect(diff.unaffected).to be_empty
        end
      end

      context 'when an instance adds a network and ip' do
        let(:spec_json) do
          {
              'networks' => {
                  'net-name' => {'ip' => '1234'},
                  'net-name-2' => {'ip' => '9876'},
              }
          }
        end

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end

        it 'inserts a record for the new network and ip' do
          local_dns_repo.update_for_instance(instance_model)

          records = Models::LocalDnsRecord.all
          expect(records.size).to eq(2)

          new_local_dns_record = records.find { |r| r.ip == '9876' }
          expect(new_local_dns_record.ip).to eq('9876')
          expect(new_local_dns_record.az).to eq('az1')
          expect(new_local_dns_record.network).to eq('net-name-2')
          expect(new_local_dns_record.deployment).to eq('bosh.1')
          expect(new_local_dns_record.instance_group).to eq('instance-group-0')
          expect(new_local_dns_record.instance).to eq(instance_model)
        end

        it 'does not delete the record for the original ip' do
          local_dns_repo.update_for_instance(instance_model)

          original_record = Models::LocalDnsRecord.order(:id).first
          expect(original_record).to eq(local_dns_record_0)
        end

        it 'will compute the difference between the instance model and the existing local dns records' do
          diff = local_dns_repo.diff(instance_model)

          expect(diff.obsolete).to be_empty
          expect(diff.missing).to eq([{
            :ip => '9876',
            :instance_id => 1,
            :az => 'az1',
            :network => 'net-name-2',
            :deployment => 'bosh.1',
            :instance_group => 'instance-group-0',
          }])
          expect(diff.unaffected).to eq([{
            :ip => record_0_ip,
            :instance_id => instance_model.id,
            :az => 'az1',
            :network => 'net-name',
            :deployment => 'bosh.1',
            :instance_group => 'instance-group-0',
          }])
        end
      end

      context 'when an instance removes an ip' do
        let(:spec_json) { {'networks' => {'net-name-2' => {'ip' => '9876'}}} }

        let!(:local_dns_record_1) do
          Models::LocalDnsRecord.create(
              :ip => '9876',
              :instance => instance_model,
              :az => 'az1',
              :network => 'net-name-2',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-0'
          )
        end

        it 'should delete the obsolete record' do
          local_dns_repo.update_for_instance(instance_model)
          expect(Models::LocalDnsRecord.exclude(instance_id: nil).all).to contain_exactly(local_dns_record_1)
        end

        it 'should insert a tombstone' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.where(instance_id: nil).count }.by(1)
        end

        it 'should have a higher max id' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end
      end

      context 'when an instance removes multiple ips' do
        let(:spec_json) { {'networks' => []} }

        let!(:local_dns_record_1) do
          Models::LocalDnsRecord.create(
              :ip => '9876',
              :instance => instance_model,
              :az => 'az1',
              :network => 'net-name-2',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-0'
          )
        end

        it 'should delete the obsolete records' do
          expect(Models::LocalDnsRecord.exclude(instance_id: nil).all.size).to eq(2)
          local_dns_repo.update_for_instance(instance_model)
          expect(Models::LocalDnsRecord.exclude(instance_id: nil).all).to be_empty
        end

        it 'should insert a single tombstone' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.where(instance_id: nil).count }.by(1)
        end

        it 'will compute the difference between the instance model and the existing local dns records' do
          diff = local_dns_repo.diff(instance_model)

          expect(diff.obsolete).to eq([
            {
              :ip => record_0_ip,
              :instance_id => instance_model.id,
              :az => 'az1',
              :network => 'net-name',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-0',
            },
            {
              :ip => '9876',
              :instance_id => instance_model.id,
              :az => 'az1',
              :network => 'net-name-2',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-0',
            },
          ])

          expect(diff.missing).to be_empty
          expect(diff.unaffected).to be_empty
        end
      end

      it 'causes the max id to increase when instance deployment changes' do
        instance_model.update('deployment' =>  Models::Deployment.make(name: 'bosh.2'))
        expect {
          local_dns_repo.update_for_instance(instance_model)
        }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
      end

      it 'causes the max id to increase when instance availability_zone changes' do
        instance_model.update('availability_zone' => 'az2')
        expect {
          local_dns_repo.update_for_instance(instance_model)
        }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
      end

      it 'causes the max id to increase when instance job changes' do
        instance_model.update('job' => 'instance-group-1')
        expect {
          local_dns_repo.update_for_instance(instance_model)
        }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
      end

      context 'when the network name changes' do
        let(:spec_json) { {'networks' => {'net-name-2' => {'ip' => '1234'}}} }

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end

        it 'inserts a record for the new network' do
          local_dns_repo.update_for_instance(instance_model)

          records = Models::LocalDnsRecord.all
          expect(records.size).to eq(1)

          new_local_dns_record = records.first
          expect(new_local_dns_record.ip).to eq('1234')
          expect(new_local_dns_record.az).to eq('az1')
          expect(new_local_dns_record.network).to eq('net-name-2')
          expect(new_local_dns_record.deployment).to eq('bosh.1')
          expect(new_local_dns_record.instance_group).to eq('instance-group-0')
          expect(new_local_dns_record.instance).to eq(instance_model)
        end
      end

      context 'when multiple updates occur' do
        let(:spec_json) do
          {
              'networks' => {
                  'net-name' => {'ip' => '1234'},
                  'net-name-2' => {'ip' => '9876'},
              }
          }
        end

        before do
          local_dns_repo.update_for_instance(instance_model)
          spec = instance_model.spec
          spec['networks']['net-name-3'] = {'ip' => '3233'}
          instance_model.spec = spec
        end

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
          expect(Models::LocalDnsRecord.all.map(&:id)).to contain_exactly(1, 2, 3)
        end

        it 'inserts a record for the new network and ip' do
          local_dns_repo.update_for_instance(instance_model)

          records = Models::LocalDnsRecord.order(:id).all
          expect(records.size).to eq(3)

          record = records[0]
          expect(record.ip).to eq('1234')
          expect(record.az).to eq('az1')
          expect(record.network).to eq('net-name')
          expect(record.deployment).to eq('bosh.1')
          expect(record.instance_group).to eq('instance-group-0')
          expect(record.instance.id).to eq(instance_model.id)

          record = records[1]
          expect(record.ip).to eq('9876')
          expect(record.az).to eq('az1')
          expect(record.network).to eq('net-name-2')
          expect(record.deployment).to eq('bosh.1')
          expect(record.instance_group).to eq('instance-group-0')
          expect(record.instance.id).to eq(instance_model.id)

          record = records[2]
          expect(record.ip).to eq('3233')
          expect(record.az).to eq('az1')
          expect(record.network).to eq('net-name-3')
          expect(record.deployment).to eq('bosh.1')
          expect(record.instance_group).to eq('instance-group-0')
          expect(record.instance.id).to eq(instance_model.id)
        end

        it 'does not delete the record for the original ip' do
          local_dns_repo.update_for_instance(instance_model)

          original_record = Models::LocalDnsRecord.order(:id).first
          expect(original_record).to eq(local_dns_record_0)
        end

        it 'logs' do
          expect(logger).to receive(:debug).with("Updating local dns records for 'instance-group-0/uuid (1)': obsolete records: [], new records: [net-name-3/3233], unmodified records: [net-name-2/9876, net-name/1234]")
          local_dns_repo.update_for_instance(instance_model)
        end
      end

      context 'when the spec does not contain a networks block' do
        let(:spec_json) { {'networks' => nil} }

        it 'deletes all the records' do
          local_dns_repo.update_for_instance(instance_model)
          expect(Models::LocalDnsRecord.exclude(instance_id: nil).count).to eq(0)
        end

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end
      end

      context 'when the spec is nil' do
        before do
          instance_model.update(spec: nil)
        end

        it 'deletes all the records' do
          local_dns_repo.update_for_instance(instance_model)
          expect(Models::LocalDnsRecord.exclude(instance_id: nil).count).to eq(0)
        end

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end
      end

      context 'when the spec[ip] is nil' do
        let(:spec_json) do
          {
              'networks' => {
                  'net-name' => {'ip' => nil},
                  'net-name-2' => {'ip' => '9876'},
              }
          }
        end

        let!(:local_dns_record_1) do
          Models::LocalDnsRecord.create(
              :ip => '9876',
              :instance => instance_model,
              :az => 'az1',
              :network => 'net-name-2',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-0'
          )
        end

        it 'deletes the record for that network name' do
          local_dns_repo.update_for_instance(instance_model)
          expect(Models::LocalDnsRecord.exclude(instance_id: nil)).to contain_exactly(local_dns_record_1)
        end

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.update_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end
      end
    end

    context 'delete for instance' do
      context 'when an instance has records' do
        let(:instance_model_too) do
          Models::Instance.make(
              uuid: 'uuidtoo',
              index: 2,
              deployment: deployment_model,
              job: 'instance-group-whatever',
              availability_zone: 'az1',
              spec_json: JSON.dump({'networks' => {'net-name-2' => {'ip' => '9876too'}}}),
          )
        end

        let!(:local_dns_record_too) do
          Models::LocalDnsRecord.create(
              :ip => '9876too',
              :instance => instance_model_too,
              :az => 'az1',
              :network => 'net-name-2',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-whatever'
          )
        end

        let!(:local_dns_record_1) do
          Models::LocalDnsRecord.create(
              :ip => '9876',
              :instance => instance_model,
              :az => 'az1',
              :network => 'net-name-2',
              :deployment => 'bosh.1',
              :instance_group => 'instance-group-0'
          )
        end

        it 'deletes the records' do
          local_dns_repo.delete_for_instance(instance_model)
          expect(Models::LocalDnsRecord.exclude(instance_id: nil).all).to eq([local_dns_record_too])
        end

        it 'causes the max id to increase' do
          expect {
            local_dns_repo.delete_for_instance(instance_model)
          }.to change { Models::LocalDnsRecord.max(:id) }.by(1)
        end
      end

      context 'when an instance does not have records' do
        before do
          Models::LocalDnsRecord.where(instance_id: instance_model.id).delete
        end

        it 'does not cause the max id to increase' do
          expect {
            local_dns_repo.delete_for_instance(instance_model)
          }.to_not change { Models::LocalDnsRecord.max(:id) }
        end
      end
    end
  end
end
