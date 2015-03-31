require 'rspec'

shared_examples_for 'All Stemcells' do

  context 'building a new stemcell' do
    describe file '/var/vcap/bosh/etc/stemcell_version' do
      let(:expected_version) { ENV['CANDIDATE_BUILD_NUMBER'] || ENV['STEMCELL_BUILD_NUMBER'] || '0000' }

      it { should be_file }
      it { should contain expected_version }
    end
  end
end
