require 'spec_helper'

describe Bosh::Director::Jobs::Ssh do
  subject { described_class.new('FAKE_DEPLOYMENT_ID') }

  describe 'Resque job class expectations' do
    let(:job_type) { :ssh }
    it_behaves_like 'a Resque job'
  end
end
