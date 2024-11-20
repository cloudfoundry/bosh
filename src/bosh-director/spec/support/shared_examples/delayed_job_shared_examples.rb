shared_examples_for 'a DelayedJob job' do
  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq job_type
    end
  end

  describe 'queue' do
    it 'has a symbol set for a DJ queue' do
      expect(described_class.instance_variable_get(:'@queue')).to eq queue
    end
  end
end
