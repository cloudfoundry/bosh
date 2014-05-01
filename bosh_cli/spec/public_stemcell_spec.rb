require 'spec_helper'
require 'cli/public_stemcell'

module Bosh::Cli
  describe PublicStemcell do
    context 'when bosh stemcell has a not patched version' do
      subject(:public_stemcell) do
        PublicStemcell.new('bosh-stemcell/aws/bosh-stemcell-1341-aws-xen-ubuntu.tgz', 383487957)
      end

      its(:name) { should eq('bosh-stemcell-1341-aws-xen-ubuntu.tgz') }
      its(:version) { should eq(1341) }
      its(:url) { should eq('https://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/bosh-stemcell-1341-aws-xen-ubuntu.tgz') }
      its(:size) { should eq(383487957) }
      its(:variety) { should eq('aws-xen-ubuntu') }
    end

    context 'when bosh stemcell has a patched version' do
      subject(:public_stemcell) do
        PublicStemcell.new('bosh-stemcell/aws/bosh-stemcell-1341_2-aws-xen-ubuntu.tgz', 383487957)
      end

      its(:name) { should eq('bosh-stemcell-1341_2-aws-xen-ubuntu.tgz') }
      its(:version) { should eq(1341.2) }
      its(:url) { should eq('https://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/bosh-stemcell-1341_2-aws-xen-ubuntu.tgz') }
      its(:size) { should eq(383487957) }
      its(:variety) { should eq('aws-xen-ubuntu') }
    end

    context 'when bosh stemcell is light' do
      subject(:public_stemcell) do
        PublicStemcell.new('bosh-stemcell/aws/light-bosh-stemcell-1341-aws-xen-ubuntu.tgz', 383487957)
      end

      its(:name) { should eq('light-bosh-stemcell-1341-aws-xen-ubuntu.tgz') }
      its(:version) { should eq(1341) }
      its(:url) { should eq('https://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/light-bosh-stemcell-1341-aws-xen-ubuntu.tgz') }
      its(:size) { should eq(383487957) }
      its(:variety) { should eq('light-aws-xen-ubuntu') }
    end
  end
end
