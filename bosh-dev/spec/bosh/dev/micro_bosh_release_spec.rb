require 'spec_helper'
require 'bosh/dev/micro_bosh_release'

module Bosh::Dev
  describe MicroBoshRelease do
    include FakeFS::SpecHelpers

    describe '#tarball' do
      before do
        FileUtils.mkdir_p('release/config')
        FileUtils.mkdir_p('release/dev_releases')
        FileUtils.touch('release/config/bosh-dev-template.yml')
      end

      it 'creates a new release tarball' do
        Rake::FileUtilsExt.should_receive(:sh).with('bosh create release --force --with-tarball') do
          FileUtils.touch('dev_releases/bosh-really-old.tgz')
          FileUtils.touch('dev_releases/bosh-previous.tgz')
          FileUtils.touch('dev_releases/bosh-just-created.tgz')
        end

        expect(subject.tarball).to include('bosh-dev/lib/bosh/dev/../../../../release/dev_releases/bosh-just-created.tgz')
      end
    end
  end
end
