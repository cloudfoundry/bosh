require 'spec_helper'
require 'bosh/dev/vm_command/build_and_publish_os_image_command'

module Bosh::Dev
  describe VmCommand::BuildAndPublishOsImageCommand do
    subject(:command) { VmCommand::BuildAndPublishOsImageCommand.new(env, options) }

    let(:env) do
      {
        'BOSH_AWS_ACCESS_KEY_ID' => 'fake-BOSH_AWS_ACCESS_KEY_ID',
        'BOSH_AWS_SECRET_ACCESS_KEY' => 'fake-BOSH_AWS_SECRET_ACCESS_KEY',
      }
    end

    let(:options) do
      {
        operating_system_name: 'ubuntu',
        operating_system_version: 'trusty',
        os_image_s3_bucket_name: 'bosh-os-images',
        os_image_s3_key: 'bosh-ubuntu-trusty-os-image.tgz',
      }
    end

    let(:tempfile) { instance_double(Tempfile, close: nil, unlink: nil, path: '/tmpdir/tmpfile') }
    before do
      allow(tempfile).to receive(:unlink) do
        allow(tempfile).to receive(:path).and_return(nil)
      end
    end
    before { class_double(Tempfile, new: tempfile).as_stubbed_const }

    describe '#to_s' do
      it 'is the command to execute on vagrant to build and publish an OS image' do
        expect(tempfile).to receive(:close).ordered
        expect(tempfile).to receive(:unlink).ordered

        expected_cmd = strip_heredoc(<<-BASH)
          set -eu
          cd /bosh

          export BOSH_AWS_ACCESS_KEY_ID='fake-BOSH_AWS_ACCESS_KEY_ID'
          export BOSH_AWS_SECRET_ACCESS_KEY='fake-BOSH_AWS_SECRET_ACCESS_KEY'

          bundle exec rake stemcell:build_os_image[ubuntu,trusty,/tmpdir/tmpfile]
          bundle exec rake stemcell:upload_os_image[/tmpdir/tmpfile,bosh-os-images,bosh-ubuntu-trusty-os-image.tgz]
        BASH

        expect(strip_heredoc(subject.to_s)).to eq(strip_heredoc(expected_cmd))
      end
    end

    def strip_heredoc(str)
      str.gsub(/^\s+/, '')
    end
  end
end

