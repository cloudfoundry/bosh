require 'spec_helper'

module Bosh::AwsCliPlugin
  describe Destroyer do
    subject(:destroyer) { Bosh::AwsCliPlugin::Destroyer.new(ui, config, rds_destroyer, vpc_destroyer) }
    let(:config) { { 'aws' => { fake: 'aws config' } } }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:rds_destroyer) { instance_double('Bosh::AwsCliPlugin::RdsDestroyer') }
    let(:vpc_destroyer) { instance_double('Bosh::AwsCliPlugin::VpcDestroyer') }

    describe '#ensure_not_production!' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      before { allow(ec2).to receive_messages(instances_count: 0) }
      before { allow(ec2).to receive_messages(volume_count: 0) }

      context 'when the environment has more than 20 instances' do
        before { allow(ec2).to receive_messages(instances_count: 21) }

        it 'assumes it is production and aborts' do
          expect {
            destroyer.ensure_not_production!
          }.to raise_error(/instance\(s\) .* aborting/)
        end
      end

      context 'when the environment has 20 or less instances' do
        before { allow(ec2).to receive_messages(instances_count: 20) }

        it 'assumes it is not production and continues' do
          destroyer.ensure_not_production!
        end
      end

      context 'when the environment has more than 20 volumes' do
        before { allow(ec2).to receive_messages(volume_count: 21) }

        it 'assumes it is production and aborts' do
          expect {
            destroyer.ensure_not_production!
          }.to raise_error(/volume\(s\) .* aborting/)
        end
      end

      context 'when the environment has 20 or less volumes' do
        before { allow(ec2).to receive_messages(volume_count: 20) }

        it 'assumes it is not production and continues' do
          destroyer.ensure_not_production!
        end
      end
    end

    describe '#delete_all_elbs' do
      it 'removes all ELBs' do
        allow(ui).to receive_messages(confirmed?: true)

        fake_elb = instance_double('Bosh::AwsCliPlugin::ELB')
        allow(Bosh::AwsCliPlugin::ELB).to receive(:new).with(fake: 'aws config').and_return(fake_elb)

        expect(fake_elb).to receive(:delete_elbs)
        expect(fake_elb).to receive(:names).and_return(%w(one two))

        destroyer.delete_all_elbs
      end
    end

    describe '#destroy_all_ec2' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      before { allow(ui).to receive_messages(say: nil) }

      context 'when there is at least one instance' do
        before { allow(ec2).to receive_messages(instance_names: { 'i1' => 'instance1-name', 'i2' => 'instance2-name' }) }

        it 'warns the user that the operation is destructive and list the instances' do
          expect(ui).to receive(:say).with(/DESTRUCTIVE OPERATION/)
          expect(ui).to receive(:say).with("Instances:\n\tinstance1-name (id: i1)\n\tinstance2-name (id: i2)")

          expect(ui).to receive(:confirmed?)
            .with(/terminate all .* EC2 instances .* non-persistent EBS/)
            .and_return(false)

          destroyer.delete_all_ec2
        end

        context 'when the user agrees to terminate all the instances' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'terminates all instances' do
            expect(ec2).to receive(:terminate_instances)
            destroyer.delete_all_ec2
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not terminate any instances' do
            expect(ec2).not_to receive(:terminate_instances)
            destroyer.delete_all_ec2
          end
        end
      end

      context 'when there is no instances' do
        before { allow(ec2).to receive_messages(instance_names: {}) }

        it 'notifies user that there is no ec2 instances' do
          expect(ui).to receive(:say).with(/No EC2 instances/)
          destroyer.delete_all_ec2
        end

        it 'does not terminate any instances' do
          expect(ec2).not_to receive(:terminate_instances)
          destroyer.delete_all_ec2
        end
      end
    end

    describe '#delete_all_ebs' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      before { allow(ui).to receive(:say) }

      it 'should warn the user that the operation is destructive and list number of volumes to be deleted' do
        allow(ec2).to receive_messages(volume_count: 2)

        expect(ui).to receive(:say).with(/DESTRUCTIVE OPERATION/)
        expect(ui).to receive(:say).with('It will delete 2 EBS volume(s)')

        expect(ui).to receive(:confirmed?)
          .with('Are you sure you want to delete all unattached EBS volumes?')
          .and_return(false)

        destroyer.delete_all_ebs
      end

      context 'where there is at least one volume' do
        before { allow(ec2).to receive_messages(volume_count: 1) }

        context 'when the user agrees to terminate all the instances' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'terminates all instances' do
            expect(ec2).to receive(:delete_volumes)
            destroyer.delete_all_ebs
          end
        end

        context 'when the user wants to bail out of ec2 termination' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not terminate any instances' do
            expect(ec2).not_to receive(:delete_volumes)
            destroyer.delete_all_ebs
          end
        end
      end

      context 'where there are no volumes' do
        before { allow(ec2).to receive_messages(volume_count: 0) }

        it 'notifies user that there is no volumes' do
          expect(ui).to receive(:say).with(/No EBS volumes/)
          destroyer.delete_all_ebs
        end

        it 'does not try to terminate any volumes' do
          expect(ec2).not_to receive(:delete_volumes)
          destroyer.delete_all_ebs
        end
      end
    end

    describe '#delete_all_rds' do
      it 'delegates to rds_destroyer' do
        expect(rds_destroyer).to receive(:delete_all)
        destroyer.delete_all_rds
      end
    end

    describe '#delete_all_s3' do
      before { allow(Bosh::AwsCliPlugin::S3).to receive(:new).with(fake: 'aws config').and_return(s3) }
      let(:s3) { instance_double('Bosh::AwsCliPlugin::S3') }

      context 'when there is at least one bucket' do
        before { allow(s3).to receive_messages(bucket_names: ['bucket1-name', 'bucket2-name']) }

        it 'warns the user that the operation is destructive and list the buckets' do
          expect(ui).to receive(:say).with(/DESTRUCTIVE OPERATION/)
          expect(ui).to receive(:say).with("Buckets:\n\tbucket1-name\n\tbucket2-name")
          expect(ui).to receive(:confirmed?).with('Are you sure you want to empty and delete all buckets?').and_return(false)
          destroyer.delete_all_s3
        end

        context 'when user confirmed deletion' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'delete all S3 buckets associated with an account' do
            expect(s3).to receive(:empty)
            destroyer.delete_all_s3
          end
        end

        context 'when user does not confirm deletion' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not delete any S3 buckets' do
            expect(s3).not_to receive(:empty)
            destroyer.delete_all_s3
          end
        end
      end

      context 'where there are no s3 buckets' do
        before { allow(s3).to receive_messages(bucket_names: []) }

        it 'notifies user that there is no buckets' do
          expect(ui).to receive(:say).with(/No S3 buckets/)
          destroyer.delete_all_s3
        end

        it 'does not delete any S3 buckets' do
          expect(s3).not_to receive(:empty)
          destroyer.delete_all_s3
        end
      end
    end

    describe '#delete_all_vpcs' do
      it 'delegates to vpc_destroyer' do
        expect(vpc_destroyer).to receive(:delete_all)
        destroyer.delete_all_vpcs
      end
    end

    describe '#delete_all_key_pairs' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      context 'when user confirmed deletion' do
        before { allow(ui).to receive_messages(confirmed?: true) }

        it 'removes all key pairs' do
          expect(ec2).to receive(:remove_all_key_pairs)
          destroyer.delete_all_key_pairs
        end
      end

      context 'when user did not confirm deletion' do
        before { allow(ui).to receive_messages(confirmed?: false) }

        it 'does not remove any key pairs' do
          expect(ec2).not_to receive(:remove_all_key_pairs)
          destroyer.delete_all_key_pairs
        end
      end
    end

    describe '#delete_all_elastic_ips' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      context 'when user confirmed deletion' do
        before { allow(ui).to receive_messages(confirmed?: true) }

        it 'removes all elastic ips' do
          expect(ec2).to receive(:release_all_elastic_ips)
          destroyer.delete_all_elastic_ips
        end
      end

      context 'when user did not confirm deletion' do
        before { allow(ui).to receive_messages(confirmed?: false) }

        it 'does not remove elastic ips' do
          expect(ec2).not_to receive(:release_all_elastic_ips)
          destroyer.delete_all_elastic_ips
        end
      end
    end

    describe '#delete_all_security_groups' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      context 'when user confirmed deletion' do
        before { allow(ui).to receive_messages(confirmed?: true) }

        it 'retries if it can not delete security groups due to eventual consistency' do
          expect(ec2).to receive(:delete_all_security_groups)
            .ordered
            .exactly(119).times
            .and_raise(::AWS::EC2::Errors::InvalidGroup::InUse)
          expect(ec2).to receive(:delete_all_security_groups)
            .ordered
            .once
            .and_return(true)
          destroyer.delete_all_security_groups(0) # sleep 0
        end
      end

      context 'when user did not confirm deletion' do
        before { allow(ui).to receive_messages(confirmed?: false) }

        it 'should not delete security groups' do
          expect(ec2).not_to receive(:delete_all_security_groups)
          destroyer.delete_all_security_groups
        end
      end
    end

    describe '#delete_all_route53_records' do
      before { allow(Bosh::AwsCliPlugin::Route53).to receive(:new).with(fake: 'aws config').and_return(route53) }
      let(:route53) { instance_double('Bosh::AwsCliPlugin::Route53') }

      context 'when omit types are specified' do
        before { allow(ui).to receive_messages(options: {omit_types: %w(custom)}) }

        context 'when user confirmed deletion' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'removes all route 53 records except user specified' do
            expect(route53).to receive(:delete_all_records).with(omit_types: %w(custom))
            destroyer.delete_all_route53_records
          end
        end

        context 'when user did not confirm deletion' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not remove 53 records' do
            expect(route53).not_to receive(:delete_all_records)
            destroyer.delete_all_route53_records
          end
        end
      end

      context 'when omit types are not specified' do
        before { allow(ui).to receive_messages(options: {}) }

        context 'when user confirmed deletion' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'removes all route 53 records except NS and SOA' do
            expect(route53).to receive(:delete_all_records).with(omit_types: %w(NS SOA))
            destroyer.delete_all_route53_records
          end
        end

        context 'when user did not confirm deletion' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not remove 53 records' do
            expect(route53).not_to receive(:delete_all_records)
            destroyer.delete_all_route53_records
          end
        end
      end
    end
  end
end
