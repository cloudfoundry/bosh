require 'spec_helper'
require 'bosh/stemcell/disk_image'

module Bosh::Stemcell
  describe DiskImage do
    let(:shell) { instance_double('Bosh::Core::Shell', run: nil) }

    let(:kpartx_output) { 'add map FAKE_LOOP1p1 (252:3): 0 3997984 linear /dev/loop1 63' }
    let(:options) do
      {
        image_file_path: '/path/to/FAKE_IMAGE',
        image_mount_point: '/fake/mnt'
      }
    end

    subject(:disk_image) { DiskImage.new(options) }

    before do
      Bosh::Core::Shell.stub(:new).and_return(shell)
    end

    describe '#initialize' do
      it 'requires an image_file_path' do
        options.delete(:image_file_path)
        expect { DiskImage.new(options) }.to raise_error /key not found: :image_file_path/
      end

      it 'requires an mount_point' do
        options.delete(:image_mount_point)
        expect { DiskImage.new(options) }.to raise_error /key not found: :image_mount_point/
      end
    end

    describe '#mount' do
      it 'maps the file to a loop device' do
        shell.should_receive(:run).with('sudo kpartx -av /path/to/FAKE_IMAGE',
                                        output_command: true).and_return(kpartx_output)

        disk_image.mount
      end

      it 'mounts the loop device' do
        shell.stub(:run).with('sudo kpartx -av /path/to/FAKE_IMAGE', output_command: true).and_return(kpartx_output)

        shell.should_receive(:run).with('sudo mount /dev/mapper/FAKE_LOOP1p1 /fake/mnt', output_command: true)

        disk_image.mount
      end
    end

    describe '#unmount' do
      it 'unmounts the loop device and then unmaps the file' do
        shell.should_receive(:run).with('sudo umount /fake/mnt', output_command: true).ordered
        shell.should_receive(:run).with('sudo kpartx -dv /path/to/FAKE_IMAGE', output_command: true).ordered

        disk_image.unmount
      end

      it 'unmaps the file even if unmounting the device fails' do
        shell.should_receive(:run).with('sudo umount /fake/mnt', output_command: true).and_raise
        shell.should_receive(:run).with('sudo kpartx -dv /path/to/FAKE_IMAGE', output_command: true).ordered

        expect { disk_image.unmount }.to raise_error
      end
    end

    describe '#while_mounted' do
      it 'mounts the disk, calls the provided block, and unmounts' do
        fake_thing = double('FakeThing')
        shell.stub(:run).with('sudo kpartx -av /path/to/FAKE_IMAGE', output_command: true).and_return(kpartx_output)
        shell.should_receive(:run).with('sudo mount /dev/mapper/FAKE_LOOP1p1 /fake/mnt', output_command: true)
        fake_thing.should_receive(:fake_call).with(disk_image).ordered
        shell.should_receive(:run).with('sudo umount /fake/mnt', output_command: true).ordered
        shell.should_receive(:run).with('sudo kpartx -dv /path/to/FAKE_IMAGE', output_command: true).ordered

        disk_image.while_mounted do |image|
          fake_thing.fake_call(image)
        end
      end

      context 'when the block raises and error' do
        it 'mounts the disk, calls the provided block, and unmounts' do
          shell.stub(:run).with('sudo kpartx -av /path/to/FAKE_IMAGE', output_command: true).and_return(kpartx_output)
          shell.should_receive(:run).with('sudo mount /dev/mapper/FAKE_LOOP1p1 /fake/mnt', output_command: true)

          shell.should_receive(:run).with('sudo umount /fake/mnt', output_command: true).ordered
          shell.should_receive(:run).with('sudo kpartx -dv /path/to/FAKE_IMAGE', output_command: true).ordered

          expect{ disk_image.while_mounted { |_| raise } }.to raise_error
        end
      end
    end
  end
end
