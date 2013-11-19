require 'spec_helper'
require 'cli/public_stemcell'

module Bosh::Cli
  describe PublicStemcell do
    subject(:public_stemcell) do
      PublicStemcell.new('bosh-stemcell/aws/bosh-stemcell-1341-aws-xen-ubuntu.tgz', 383487957)
    end

    its(:name) { should eq('bosh-stemcell-1341-aws-xen-ubuntu.tgz') }
    its(:version) { should eq(1341) }
    its(:url) { should eq('https://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/bosh-stemcell-1341-aws-xen-ubuntu.tgz')}
    its(:size) { should eq(383487957)}
  end
end
