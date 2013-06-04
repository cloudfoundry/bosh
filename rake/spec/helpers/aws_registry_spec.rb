require 'spec_helper'
require_relative '../../lib/helpers/aws_registry'

module Bosh
  module Helpers
    describe AwsRegistry do
      it 'queries AWS for its region' do
        Net::HTTP.stub(:get).with('169.254.169.254', '/latest/meta-data/placement/availability-zone').and_return("us-east-1\n")
        expect(subject.region).to eq 'us-east-1'
      end
    end
  end
end
