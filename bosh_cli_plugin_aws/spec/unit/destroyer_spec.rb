require 'spec_helper'

module Bosh::Aws
  describe Destroyer do
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }

    subject(:destroyer) { Bosh::Aws::Destroyer.new(ui) }

    describe '#delete_all_elbs' do
      it 'removes all ELBs' do
        ui.stub(:confirmed?).and_return(true)

        fake_elb = instance_double('Bosh::Aws::ELB')
        Bosh::Aws::ELB.stub(:new).with(fake: 'aws config').and_return(fake_elb)

        fake_elb.should_receive(:delete_elbs)
        fake_elb.should_receive(:names).and_return(%w(one two))

        destroyer.delete_all_elbs('aws' => { fake: 'aws config' })
      end
    end
  end
end
