require 'spec_helper'

module Bosh::Aws
  describe Destroyer do
    let(:config) do
      { 'aws' => { fake: 'aws config' } }
    end
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    subject(:destroyer) { Bosh::Aws::Destroyer.new(ui) }

    describe '#ensure_not_production!' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when the environment has more than 20 instances' do
        before { ec2.stub(instances_count: 21) }

        it 'assumes it is production and aborts' do
          expect {
            destroyer.ensure_not_production!(config)
          }.to raise_error(/aborting/)
        end
      end

      context 'when the environment has 20 or less instances' do
        before { ec2.stub(instances_count: 20) }

        it 'assumes it is not production and continues' do
          destroyer.ensure_not_production!(config)
        end
      end
    end

    describe '#delete_all_elbs' do
      it 'removes all ELBs' do
        ui.stub(:confirmed?).and_return(true)

        fake_elb = instance_double('Bosh::Aws::ELB')
        Bosh::Aws::ELB.stub(:new).with(fake: 'aws config').and_return(fake_elb)

        fake_elb.should_receive(:delete_elbs)
        fake_elb.should_receive(:names).and_return(%w(one two))

        destroyer.delete_all_elbs(config)
      end
    end
  end
end
