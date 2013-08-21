require 'spec_helper'
require 'bosh/stemcell/aws_registry'

module Bosh::Stemcell
  describe AwsRegistry do
    it 'queries AWS for its region' do
      az_query = '/latest/meta-data/placement/availability-zone'
      Net::HTTP.stub(:get).with('169.254.169.254', az_query).and_return("us-east-1\n")
      expect(subject.region).to eq 'us-east-1'
    end
  end
end
