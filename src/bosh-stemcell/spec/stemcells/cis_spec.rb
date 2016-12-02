require 'spec_helper'

describe 'CIS test case verification', {stemcell_image: true, security_spec: true} do
  let(:base_cis_test_cases) do %W{
        CIS-2.18
        CIS-2.19
        CIS-2.20
        CIS-2.21
        CIS-2.22
        CIS-2.23
        CIS-4.1
        CIS-7.2.5
        CIS-7.2.6
        CIS-7.2.7
        CIS-7.3.1
        CIS-7.3.2
        CIS-7.5.3
        CIS-11.1
        CIS-8.1.3
        CIS-8.1.4
        CIS-8.1.5
        CIS-8.1.6
        CIS-8.1.7
        CIS-8.1.8
        CIS-8.1.9
        CIS-8.1.10
        CIS-8.1.11
        CIS-8.1.12
        CIS-8.1.13
        CIS-8.1.14
        CIS-8.1.15
        CIS-8.1.16
        CIS-8.1.18
        CIS-9.1.2
        CIS-9.1.3
        CIS-9.1.4
        CIS-9.1.5
        CIS-9.1.6
        CIS-9.1.7
        CIS-9.1.8
        CIS-9.2.1
        CIS-9.4
        CIS-9.5
        CIS-10.2
      }
  end


  context "For all infrastructure except Azure", {exclude_on_azure:true} do
    it 'confirms that all CIS test cases ran' do
      expected_base_cis_test_cases = base_cis_test_cases
      expected_base_cis_test_cases << 'CIS-2.24'

      expected_cis_test_cases = expected_base_cis_test_cases
      case ENV['OS_NAME']
        when 'ubuntu'
          expected_cis_test_cases = expected_base_cis_test_cases + [
          ]
        when 'centos'
          expected_cis_test_cases = expected_base_cis_test_cases + [
            'CIS-6.7'
          ]
        when 'rhel'
          expected_cis_test_cases = expected_base_cis_test_cases + [
          ]
      end

      expect($cis_test_cases.to_a).to match_array expected_cis_test_cases
    end
  end

  context "For Azure infrastructure", {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_softlayer: true,
  } do
    it 'confirms that all CIS test cases ran' do
      expected_base_cis_test_cases = base_cis_test_cases

      expected_cis_test_cases = expected_base_cis_test_cases
      case ENV['OS_NAME']
        when 'ubuntu'
          expected_cis_test_cases = expected_base_cis_test_cases + [
          ]
        when 'centos'
          expected_cis_test_cases = expected_base_cis_test_cases + [
            'CIS-6.7'
          ]
        when 'rhel'
          expected_cis_test_cases = expected_base_cis_test_cases + [
          ]
      end

      expect($cis_test_cases.to_a).to match_array expected_cis_test_cases
    end
  end
end
