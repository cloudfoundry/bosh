require 'spec_helper'

module SpecInfra::Backend
  describe Exec do
    subject(:exec) { described_class.instance }

    describe '#run_command' do
      context 'when #chroot_dir is NOT set' do
        before { exec.stub(chroot_dir: nil) }

        it 'runs the provided command as expected' do
          exec.should_receive(:`).with('echo "FOO" 2>&1')
          exec.run_command('echo "FOO"')
        end
      end

      context 'when #chroot_dir is set' do
        before { exec.stub(chroot_dir: '/path/to/chroot') }

        it 'runs the provided command within the chroot' do
          chroot_command = %Q{
sudo chroot /path/to/chroot /bin/bash <<CHROOT_CMD
  echo "FOO" 2>&1; echo EXIT_CODE=\\$?
CHROOT_CMD
 2>&1}
          exec.should_receive(:`).with(chroot_command).and_return("FOO\nEXIT_CODE=0\n")
          exec.run_command('echo "FOO"')
        end

        it 'extracts the exit code returned from within the chroot into an Integer' do
          exec.stub(:` => "ATTENTION\nDO NOT CARE\nEXIT_CODE=8675309\n")
          result = exec.run_command('do_not_care')
          expect(result[:exit_status]).to eq(867_5309)
        end
      end
    end
  end
end
