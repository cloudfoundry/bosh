require 'spec_helper'
require 'bosh/dev/bosh_release'
require 'bosh/dev/release_creator'

module Bosh::Dev
  describe BoshRelease do
    include FakeFS::SpecHelpers

    subject { described_class.new(release_creator) }
    let(:release_creator) { instance_double('Bosh::Dev::ReleaseCreator') }

    describe '#final_tarball_path' do
      it 'return path to created bosh final release' do
        release_creator
          .should_receive(:create_final)
          .with(no_args)
          .and_return('fake-final-tarball-path')
        subject.final_tarball_path.should == 'fake-final-tarball-path'
      end
    end

    describe '#dev_tarball_path' do
      it 'return path to created bosh dev release' do
        release_creator
          .should_receive(:create_dev)
          .with(no_args)
          .and_return('fake-dev-tarball-path')
        subject.dev_tarball_path.should == 'fake-dev-tarball-path'
      end
    end
  end
end
