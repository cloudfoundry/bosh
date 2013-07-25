require 'spec_helper'

describe Bosh::Director do
  describe "helpers" do
    include Bosh::Director::ApiControllerHelpers

    describe "unzip job instances" do
      it "converts hash of job to indexes to array of job/instance tuples" do
        hash = {
          'job0' => [1, 2],
          'job1' => [1],
          'job2' => []
        }

        expect(convert_job_instance_hash(hash)).to eq [
          ['job0', 1],
          ['job0', 2],
          ['job1', 1]
        ]
      end
    end
  end
end