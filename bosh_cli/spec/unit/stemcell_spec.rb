require 'spec_helper'

describe Bosh::Cli::Stemcell do
  let(:valid_stemcell) { spec_asset('valid_stemcell.tgz') }
  let(:cache) { Bosh::Cli::Cache.new(Dir.mktmpdir) }

  describe 'verifying a stemcell' do
    it 'verifies and reports a valid stemcell' do
      subject = described_class.new(valid_stemcell, cache)
      subject.should be_valid
    end
  end
end
