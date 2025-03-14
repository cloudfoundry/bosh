require 'spec_helper'

module Bosh::Director
  describe Api::DirectorVMInfo do
    describe :get_disks_info do
      before :each do
        @df_info = <<~DF_OUTPUT
          Filesystem      Size  Used Avail Use% Mounted on
          /dev/xvdb2       13G  2.5G  9.1G  22% /
          tmpfs            64M     0   64M   0% /dev
          shm              64M     0   64M   0% /dev/shm
          /dev/xvda1      2.9G  1.5G  1.3G  55% /lib
          tmpfs           7.9G   62M  7.8G   1% /run/resolvconf
          /dev/xvdf1       63G  129M   60G   1% /var/vcap/store/director
          tmpfs           7.9G     0  7.9G   0% /etc/sv
          tmpfs           7.9G     0  7.9G   0% /sys/firmware
        DF_OUTPUT
      end

      it 'should report only the persistent and ephemeral disks' do
        disks_info = Bosh::Director::Api::DirectorVMInfo.get_disks_info(@df_info)

        expected = [
          {
            'size' => '13G',
            'available' => '9.1G',
            'used' => '22%',
            'name' => 'ephemeral',
          },
          {
            'size' => '63G',
            'available' => '60G',
            'used' => '1%',
            'name' => 'persistent',
          },
        ]

        expect(disks_info).to match(expected)
      end
    end
  end
end
