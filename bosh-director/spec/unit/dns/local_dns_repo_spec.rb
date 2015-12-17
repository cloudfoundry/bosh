require 'spec_helper'

module Bosh::Director
  describe LocalDnsRepo do
    let(:local_dns_repo) { LocalDnsRepo.new(logger) }
    let(:deployment_model) { Models::Deployment.make(name: 'dep') }
    let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model) }

    describe '#create_or_update' do
      it 'creates new records' do
        local_dns_repo.create_or_update(instance_model, ['fake-dns-record-name-1', 'fake-dns-record-name-2'])
        expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-record-name-1', 'fake-dns-record-name-2'])
      end

      context 'when record already exists' do
        before do
          local_dns_repo.create_or_update(instance_model, ['fake-dns-record-name-1', 'fake-dns-record-name-2'])
        end
        it 'updates existing records' do
          expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-record-name-1', 'fake-dns-record-name-2'])
          local_dns_repo.create_or_update(instance_model, ['fake-dns-record-name-3'])
          expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-record-name-3'])
        end
      end
    end

    describe '#delete' do
      before do
        local_dns_repo.create_or_update(instance_model, ['fake-dns-record-name-1', 'fake-dns-record-name-2'])
      end

      it 'deletes existing record' do
        expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-record-name-1', 'fake-dns-record-name-2'])
        local_dns_repo.delete(instance_model)
        expect(local_dns_repo.find(instance_model)).to eq([])
      end
    end
  end
end
