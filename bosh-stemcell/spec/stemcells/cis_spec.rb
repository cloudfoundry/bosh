require 'spec_helper'

describe 'CIS test case verification', { stemcell_image: true, cis_check: true } do

  it 'confirms that all CIS test cases ran' do
    expected_base_cis_test_cases = %W{
      CIS-7.3.1
      CIS-7.3.2
    }

    expected_cis_test_cases = expected_base_cis_test_cases
    case ENV['OS_NAME']
      when 'ubuntu'
        expected_cis_test_cases = expected_base_cis_test_cases + [
        ]
      when 'centos'
        expected_cis_test_cases = expected_base_cis_test_cases + [
        ]
    end
    expect($cis_test_cases.to_a).to match_array expected_cis_test_cases
  end
end