require 'spec_helper'

describe 'CIS test case verification', {stemcell_image: true, cis_check: true} do

  it 'confirms that all CIS test cases ran' do
    expected_base_cis_test_cases = %W{
      CIS-2.18
      CIS-2.19
      CIS-2.20
      CIS-2.21
      CIS-2.22
      CIS-2.23
      CIS-2.24
      CIS-4.1
      CIS-7.2.5
      CIS-7.2.6
      CIS-7.3.1
      CIS-7.5.3
      CIS-11.1
    }

    expected_cis_test_cases = expected_base_cis_test_cases
    case ENV['OS_NAME']
      when 'ubuntu'
        expected_cis_test_cases = expected_base_cis_test_cases + [
        ]
      when 'centos'
        expected_cis_test_cases = expected_base_cis_test_cases + [
        ]
      when 'rhel'
        expected_cis_test_cases = expected_base_cis_test_cases + [
        ]
    end
    expect($cis_test_cases.to_a).to match_array expected_cis_test_cases
  end
end
