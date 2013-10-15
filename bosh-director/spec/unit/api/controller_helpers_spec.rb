require 'spec_helper'

module Bosh::Director
  module Api
    describe ControllerHelpers do
      subject(:helpers) do
        helpers = double(Bosh::Director::Api::ControllerHelpers)
        helpers.extend(Bosh::Director::Api::ControllerHelpers)
      end

      describe 'unzip job instances' do
        it 'converts hash of job to indexes to array of job/instance tuples' do
          hash = {
            'job0' => [1, 2],
            'job1' => [1],
            'job2' => []
          }

          expect(helpers.convert_job_instance_hash(hash)).to eq [
                                                                  ['job0', 1],
                                                                  ['job0', 2],
                                                                  ['job1', 1]
                                                                ]
        end
      end
    end
  end
end
