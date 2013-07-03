require 'spec_helper'

describe Bosh::Director::Jobs::Ssh do
  subject { described_class.new('FAKE_DEPLOYMENT_ID') }

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:ssh)
    end
  end

  pending '#perform'
end
