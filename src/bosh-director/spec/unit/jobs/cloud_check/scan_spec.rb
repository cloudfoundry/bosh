require 'spec_helper'

module Bosh::Director
  describe Jobs::CloudCheck::Scan do
    describe 'DJ job class expectations' do
      let(:job_type) { :cck_scan }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe 'instance methods' do
      before do
        deployment = FactoryBot.create(:models_deployment, name: 'deployment')
        expect(ProblemScanner::Scanner).to receive(:new).with(deployment).and_return(scanner)
      end

      let(:job) { described_class.new('deployment') }
      let(:scanner) { instance_double('Bosh::Director::ProblemScanner::Scanner') }
      let(:deployment) { Models::Deployment[1] }

      it 'should obtain a deployment lock' do
        expect(job).to receive(:with_deployment_lock).and_yield

        scanner.as_null_object

        job.perform
      end

      it 'should run the scan' do
        allow(job).to receive(:with_deployment_lock).and_yield

        expect(scanner).to receive(:reset).ordered
        expect(scanner).to receive(:scan_vms).ordered
        expect(scanner).to receive(:scan_disks).ordered

        job.perform
      end
    end
  end
end
