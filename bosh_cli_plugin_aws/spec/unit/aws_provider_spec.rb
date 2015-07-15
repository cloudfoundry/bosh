require 'spec_helper'
require 'bosh_cli_plugin_aws/aws_provider'

module Bosh::AwsCliPlugin
  describe AwsProvider do
    subject(:aws_provider) { described_class.new(credentials) }

    let(:credentials) do
      { 'region' => 'FAKE_AWS_REGION' }
    end

    its(:region) { should eq('FAKE_AWS_REGION') }

    describe '#ec2' do
      let(:ec2) { instance_double('AWS::EC2') }
      let(:expected_arguments) do
        {
          'region' => 'FAKE_AWS_REGION',
          'ec2_endpoint' => 'ec2.FAKE_AWS_REGION.amazonaws.com'
        }
      end

      it 'returns a correctly configured AWS::EC2 object' do
        expect(AWS::EC2).to receive(:new).with(expected_arguments).and_return(ec2)

        expect(aws_provider.ec2).to eq(ec2)
      end

      it 'memoizes the AWS::EC2 object' do
        expect(AWS::EC2).to receive(:new).once.and_return(ec2)

        2.times { aws_provider.ec2 }
      end
    end

    describe '#elb' do
      let(:elb) { instance_double('AWS::ELB') }
      let(:credentials) do
        {
          'region' => 'FAKE_AWS_REGION',
          'elb_endpoint' => 'elasticloadbalancing.FAKE_AWS_REGION.amazonaws.com'
        }
      end

      it 'returns a correctly configured AWS::ELB object' do
        expect(AWS::ELB).to receive(:new).with(credentials).and_return(elb)

        expect(aws_provider.elb).to eq(elb)
      end

      it 'memoizes the AWS::S3 object' do
        expect(AWS::ELB).to receive(:new).once.and_return(elb)

        2.times { aws_provider.elb }
      end
    end

    describe '#iam' do
      let(:iam) { instance_double('AWS::IAM') }

      it 'returns a correctly configured AWS::IAM object' do
        expect(AWS::IAM).to receive(:new).with(credentials).and_return(iam)

        expect(aws_provider.iam).to eq(iam)
      end
      it 'memoizes the AWS::ELB object' do
        expect(AWS::IAM).to receive(:new).once.and_return(iam)

        2.times { aws_provider.iam }
      end
    end

    describe '#rds' do
      let(:rds) { instance_double('AWS::RDS') }
      let(:credentials) do
        {
          'region' => 'FAKE_AWS_REGION',
          'rds_endpoint' => 'rds.FAKE_AWS_REGION.amazonaws.com'
        }
      end

      it 'returns a correctly configured AWS::RDS object' do
        expect(AWS::RDS).to receive(:new).with(credentials).and_return(rds)

        expect(aws_provider.rds).to eq(rds)
      end

      it 'memoizes the AWS::RDS object' do
        expect(AWS::RDS).to receive(:new).once.and_return(rds)

        2.times { aws_provider.rds }
      end
    end

    describe '#rds_client' do
      let(:rds_client) { instance_double('AWS::RDS::Client') }
      let(:credentials) do
        {
          'region' => 'FAKE_AWS_REGION',
          'rds_endpoint' => 'rds.FAKE_AWS_REGION.amazonaws.com'
        }
      end

      it 'returns a correctly configured AWS::RDS::Client object' do
        expect(AWS::RDS::Client).to receive(:new).with(credentials).and_return(rds_client)

        expect(aws_provider.rds_client).to eq(rds_client)
      end

      it 'memoizes the AWS::RDS::Client object' do
        expect(AWS::RDS::Client).to receive(:new).once.and_return(rds_client)

        2.times { aws_provider.rds_client }
      end
    end

    describe '#route53' do
      let(:route53) { instance_double('AWS::Route53') }

      it 'returns a correctly configured AWS::Route53 object' do
        expect(AWS::Route53).to receive(:new).with(credentials).and_return(route53)

        expect(aws_provider.route53).to eq(route53)
      end

      it 'memoizes the AWS::Route53 object' do
        expect(AWS::Route53).to receive(:new).once.and_return(route53)

        2.times { aws_provider.route53 }
      end
    end

    describe '#s3' do
      let(:s3) { instance_double('AWS::S3') }

      it 'returns a correctly configured AWS::S3 object' do
        expect(AWS::S3).to receive(:new).with(credentials).and_return(s3)

        expect(aws_provider.s3).to eq(s3)
      end
      it 'memoizes the AWS::S3 object' do
        expect(AWS::S3).to receive(:new).once.and_return(s3)

        2.times { aws_provider.s3 }
      end
    end
  end
end
