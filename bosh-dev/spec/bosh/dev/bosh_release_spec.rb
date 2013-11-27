require 'spec_helper'
require 'bosh/dev/bosh_release'
require 'bosh/dev/release_creator'

module Bosh::Dev
  describe BoshRelease do
    include FakeFS::SpecHelpers

    subject { described_class.new(release_creator) }
    let(:release_creator) { instance_double('Bosh::Dev::ReleaseCreator') }

    describe '#tarball_path' do
      it 'creates dev and then final release' do
        release_creator.should_receive(:create).with(no_args).ordered.and_return('fake-dev-tarball-path')
        subject.tarball_path.should == 'fake-dev-tarball-path'
      end
    end
  end
end
