require 'spec_helper'

describe 'Stig test case verification', { stemcell_image: true, stig_check: true } do
  it 'confirms all stig test cases ran' do
    expected_base_stig_test_cases = %W{
      V-38682
      V-38691
      V-38614
      V-38612
      V-38615
      V-38611
      V-38608
      V-38616
      V-38610
      V-38607
      V-38701
      V-38587
      V-38589
      V-38598
      V-38591
      V-38594
      V-38602
      V-38450
      V-38451
      V-38499
      V-38458
      V-38459
      V-38461
      V-38443
      V-38448
      V-38449
      V-38643
      V-38497
      V-38491
      V-38484
      V-38613
      V-38523
      V-38524
      V-38526
      V-38529
      V-38582
      V-38548
      V-38532
      V-38600
      V-38601
      V-38583
      V-38579
      V-38581
      V-38585
      V-38462
      V-38617
      V-38465
      V-38466
      V-38469
      V-38472
      V-38674
      V-58901
      V-38658
      V-38671
      V-38609
      V-38606
      V-38605
      V-38500
      V-38604
      V-38603
      V-38504
      V-38503
      V-38502
      V-38457
      V-38517
      V-38515
      V-38514
      V-38619
      V-38490
    }

    expected_stig_test_cases = expected_base_stig_test_cases
    case ENV['OS_NAME']
      when 'ubuntu'
        expected_stig_test_cases = expected_base_stig_test_cases + [
          'V-38668',
          'V-38476'
        ]
      when 'centos'
        expected_stig_test_cases = expected_base_stig_test_cases + [
          'V-38668',
          'V-38476',
          'V-38586'
        ]
      when 'rhel'
        expected_stig_test_cases = expected_base_stig_test_cases + [
          'V-38586'
        ]
    end
    expected_stig_test_cases= expected_stig_test_cases.reject{ |s| Bosh::Stemcell::Arch.ppc64le? and
                                                ['V-38579', 'V-38581', 'V-38583', 'V-38585'].include?(s) }
    expect($stig_test_cases.to_a).to match_array expected_stig_test_cases
  end
end
