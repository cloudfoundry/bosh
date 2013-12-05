# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  it 'should delete the stemcell' do
    stemcell = double(Bosh::AwsCloud::Stemcell)

    cloud = mock_cloud do |_, region|
      Bosh::AwsCloud::StemcellFinder.stub(:find_by_region_and_id).with(region, 'ami-xxxxxxxx').and_return(stemcell)
    end

    stemcell.should_receive(:delete)

    cloud.delete_stemcell('ami-xxxxxxxx')
  end
end
