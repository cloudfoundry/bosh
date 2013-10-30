require 'spec_helper'

module Bosh::Aws
  describe Destroyer do
    let(:config) do
      { 'aws' => { fake: 'aws config' } }
    end
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    subject(:destroyer) { Bosh::Aws::Destroyer.new(ui, config) }

    describe '#ensure_not_production!' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when the environment has more than 20 instances' do
        before { ec2.stub(instances_count: 21) }

        it 'assumes it is production and aborts' do
          expect {
            destroyer.ensure_not_production!
          }.to raise_error(/aborting/)
        end
      end

      context 'when the environment has 20 or less instances' do
        before { ec2.stub(instances_count: 20) }

        it 'assumes it is not production and continues' do
          destroyer.ensure_not_production!
        end
      end
    end

    describe '#delete_all_elbs' do
      it 'removes all ELBs' do
        ui.stub(confirmed?: true)

        fake_elb = instance_double('Bosh::Aws::ELB')
        Bosh::Aws::ELB.stub(:new).with(fake: 'aws config').and_return(fake_elb)

        fake_elb.should_receive(:delete_elbs)
        fake_elb.should_receive(:names).and_return(%w(one two))

        destroyer.delete_all_elbs
      end
    end

    describe '#destroy_all_ec2' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      before { ui.stub(say: nil) }

      context 'when there is at least one instance' do
        before { ec2.stub(instances_count: 2, instance_names: { 'i1' => 'instance1-name', 'i2' => 'instance2-name' }) }

        it 'warns the user that the operation is destructive and list the instances' do
          ui.should_receive(:say).with("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)
          ui.should_receive(:say).with("Instances:\n\tinstance1-name (id: i1)\n\tinstance2-name (id: i2)")

          ui.should_receive(:confirmed?)
            .with(/terminate all .* EC2 instances .* non-persistent EBS/)
            .and_return(false)

          destroyer.delete_all_ec2
        end

        context 'when the user agrees to terminate all the instances' do
          before { ui.stub(confirmed?: true) }

          it 'terminates all instances' do
            ec2.should_receive(:terminate_instances)
            destroyer.delete_all_ec2
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          before { ui.stub(confirmed?: false) }

          it 'does not terminate any instances' do
            ec2.should_not_receive(:terminate_instances)
            destroyer.delete_all_ec2
          end
        end
      end

      context 'when there is no instances' do
        before { ec2.stub(instances_count: 0, instance_names: {}) }

        it 'notifies user that there is no ec2 instances' do
          ui.should_receive(:say).with(/No EC2 instances/)
          destroyer.delete_all_ec2
        end

        it 'does not terminate any instances' do
          ec2.should_not_receive(:terminate_instances)
          destroyer.delete_all_ec2
        end
      end
    end
  end
end
