require 'spec_helper'
require 'bosh/dev/aws/receipts'

module Bosh::Dev::Aws
  describe Receipts do
    before do
      ENV.stub(:to_hash).and_return({
                                      'BOSH_VPC_SUBDOMAIN' => 'fake_BOSH_VPC_SUBDOMAIN',
                                    })
    end

    its(:vpc_outfile_path) { should eq('/mnt/deployments/fake_BOSH_VPC_SUBDOMAIN/aws_vpc_receipt.yml') }
    its(:route53_outfile_path) { should eq('/mnt/deployments/fake_BOSH_VPC_SUBDOMAIN/aws_route53_receipt.yml') }
  end
end
