require 'spec_helper'

module Bosh::Aws
  describe Destroyer do
    subject(:destroyer) { Bosh::Aws::Destroyer.new(ui, config, rds_destroyer, vpc_destroyer) }
    let(:config) { { 'aws' => { fake: 'aws config' } } }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:rds_destroyer) { instance_double('Bosh::Aws::RdsDestroyer') }
    let(:vpc_destroyer) { instance_double('Bosh::Aws::VpcDestroyer') }

    describe '#ensure_not_production!' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      before { ec2.stub(instances_count: 0) }
      before { ec2.stub(volume_count: 0) }

      context 'when the environment has more than 20 instances' do
        before { ec2.stub(instances_count: 21) }

        it 'assumes it is production and aborts' do
          expect {
            destroyer.ensure_not_production!
          }.to raise_error(/instance\(s\) .* aborting/)
        end
      end

      context 'when the environment has 20 or less instances' do
        before { ec2.stub(instances_count: 20) }

        it 'assumes it is not production and continues' do
          destroyer.ensure_not_production!
        end
      end

      context 'when the environment has more than 20 volumes' do
        before { ec2.stub(volume_count: 21) }

        it 'assumes it is production and aborts' do
          expect {
            destroyer.ensure_not_production!
          }.to raise_error(/volume\(s\) .* aborting/)
        end
      end

      context 'when the environment has 20 or less volumes' do
        before { ec2.stub(volume_count: 20) }

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
        before { ec2.stub(instance_names: { 'i1' => 'instance1-name', 'i2' => 'instance2-name' }) }

        it 'warns the user that the operation is destructive and list the instances' do
          ui.should_receive(:say).with(/DESTRUCTIVE OPERATION/)
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
        before { ec2.stub(instance_names: {}) }

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

    describe '#delete_all_ebs' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      before { ui.stub(:say) }

      it 'should warn the user that the operation is destructive and list number of volumes to be deleted' do
        ec2.stub(volume_count: 2)

        ui.should_receive(:say).with(/DESTRUCTIVE OPERATION/)
        ui.should_receive(:say).with('It will delete 2 EBS volume(s)')

        ui.should_receive(:confirmed?)
          .with('Are you sure you want to delete all unattached EBS volumes?')
          .and_return(false)

        destroyer.delete_all_ebs
      end

      context 'where there is at least one volume' do
        before { ec2.stub(volume_count: 1) }

        context 'when the user agrees to terminate all the instances' do
          before { ui.stub(confirmed?: true) }

          it 'terminates all instances' do
            ec2.should_receive(:delete_volumes)
            destroyer.delete_all_ebs
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          before { ui.stub(confirmed?: false) }

          it 'does not terminate any instances' do
            ec2.should_not_receive(:delete_volumes)
            destroyer.delete_all_ebs
          end
        end
      end

      context 'where there are no volumes' do
        before { ec2.stub(volume_count: 0) }

        it 'notifies user that there is no volumes' do
          ui.should_receive(:say).with(/No EBS volumes/)
          destroyer.delete_all_ebs
        end

        it 'does not try to terminate any volumes' do
          ec2.should_not_receive(:delete_volumes)
          destroyer.delete_all_ebs
        end
      end
    end

    describe '#delete_all_rds' do
      it 'delegates to rds_destroyer' do
        rds_destroyer.should_receive(:delete_all)
        destroyer.delete_all_rds
      end
    end

    describe '#delete_all_s3' do
      before { Bosh::Aws::S3.stub(:new).with(fake: 'aws config').and_return(s3) }
      let(:s3) { instance_double('Bosh::Aws::S3') }

      context 'when there is at least one bucket' do
        before { s3.stub(bucket_names: ['bucket1-name', 'bucket2-name']) }

        it 'warns the user that the operation is destructive and list the buckets' do
          ui.should_receive(:say).with(/DESTRUCTIVE OPERATION/)
          ui.should_receive(:say).with("Buckets:\n\tbucket1-name\n\tbucket2-name")
          ui.should_receive(:confirmed?).with('Are you sure you want to empty and delete all buckets?').and_return(false)
          destroyer.delete_all_s3
        end

        context 'when user confirmed deletion' do
          before { ui.stub(confirmed?: true) }

          it 'delete all S3 buckets associated with an account' do
            s3.should_receive(:empty)
            destroyer.delete_all_s3
          end
        end

        context 'when user does not confirm deletion' do
          before { ui.stub(confirmed?: false) }

          it 'does not delete any S3 buckets' do
            s3.should_not_receive(:empty)
            destroyer.delete_all_s3
          end
        end
      end

      context 'where there are no s3 buckets' do
        before { s3.stub(bucket_names: []) }

        it 'notifies user that there is no buckets' do
          ui.should_receive(:say).with(/No S3 buckets/)
          destroyer.delete_all_s3
        end

        it 'does not delete any S3 buckets' do
          s3.should_not_receive(:empty)
          destroyer.delete_all_s3
        end
      end
    end

    describe '#delete_all_vpcs' do
      it 'delegates to vpc_destroyer' do
        vpc_destroyer.should_receive(:delete_all)
        destroyer.delete_all_vpcs
      end
    end

    describe '#delete_all_key_pairs' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when user confirmed deletion' do
        before { ui.stub(confirmed?: true) }

        it 'removes all key pairs' do
          ec2.should_receive(:remove_all_key_pairs)
          destroyer.delete_all_key_pairs
        end
      end

      context 'when user did not confirm deletion' do
        before { ui.stub(confirmed?: false) }

        it 'does not remove any key pairs' do
          ec2.should_not_receive(:remove_all_key_pairs)
          destroyer.delete_all_key_pairs
        end
      end
    end

    describe '#delete_all_elastic_ips' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when user confirmed deletion' do
        before { ui.stub(confirmed?: true) }

        it 'removes all elastic ips' do
          ec2.should_receive(:release_all_elastic_ips)
          destroyer.delete_all_elastic_ips
        end
      end

      context 'when user did not confirm deletion' do
        before { ui.stub(confirmed?: false) }

        it 'does not remove elastic ips' do
          ec2.should_not_receive(:release_all_elastic_ips)
          destroyer.delete_all_elastic_ips
        end
      end
    end

    describe '#delete_all_security_groups' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      context 'when user confirmed deletion' do
        before { ui.stub(confirmed?: true) }

        it 'retries if it can not delete security groups due to eventual consistency' do
          ec2.should_receive(:delete_all_security_groups)
            .ordered
            .exactly(119).times
            .and_raise(::AWS::EC2::Errors::InvalidGroup::InUse)
          ec2.should_receive(:delete_all_security_groups)
            .ordered
            .once
            .and_return(true)
          destroyer.delete_all_security_groups(0) # sleep 0
        end
      end

      context 'when user did not confirm deletion' do
        before { ui.stub(confirmed?: false) }

        it 'should not delete security groups' do
          ec2.should_not_receive(:delete_all_security_groups)
          destroyer.delete_all_security_groups
        end
      end
    end
  end
end
