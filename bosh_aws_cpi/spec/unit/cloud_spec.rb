require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  describe 'validating initialization options' do
    it 'raises an error warning the user of all the missing required configurations' do
      expect {
        described_class.new(
          {
            'aws' => {
              'access_key_id' => 'keys to my heart',
              'secret_access_key' => 'open sesame'
            }
          }
        )
      }.to raise_error(ArgumentError, 'missing configuration parameters > aws:region, aws:default_key_name, registry:endpoint, registry:user, registry:password')
    end

    it 'does not raise an error if all the required configuraitons are present' do
      expect {
        described_class.new(
          {
            'aws' => {
              'access_key_id' => 'keys to my heart',
              'secret_access_key' => 'open sesame',
              'region' => 'fupa',
              'default_key_name' => 'sesame'
            },
            'registry' => {
              'user' => 'abuser',
              'password' => 'hard2gess',
              'endpoint' => 'http://websites.com'
            }
          }
        )
      }.to_not raise_error
    end
  end
end
