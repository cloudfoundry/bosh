require 'spec_helper'

describe 'director certificate expiry', type: :integration do
  with_reset_sandbox_before_each

  it 'returns a list of certificates with expiry dates' do
    result = bosh_runner.run('curl --json /director/certificate_expiry')

    expected_result = [
      { 'certificate_path' => 'director.abc.certificate', 'expiry' => /.*/, 'days_left' => -8 },
      { 'certificate_path' => 'director.abc.ca', 'expiry' => /.*/, 'days_left' => 13 },
      { 'certificate_path' => 'director.def.certificate', 'expiry' => /.*/, 'days_left' => 0 },
    ]

    array = JSON.parse(result)['Blocks'][0]
    expect(JSON.parse(array)).to match_array(expected_result)
  end
end
