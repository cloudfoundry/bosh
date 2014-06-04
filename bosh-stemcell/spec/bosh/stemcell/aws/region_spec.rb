require 'spec_helper'
require 'bosh/stemcell/aws/region'

module Bosh::Stemcell::Aws
  describe Region do
    it 'queries AWS for its region' do
      az_query = '/latest/meta-data/placement/availability-zone'
      allow(Net::HTTP).to receive(:get).with('169.254.169.254', az_query).and_return("us-east-1\n")
      expect(subject.name).to eq 'us-east-1'
    end
  end
end
