require 'spec_helper'
require 'bosh/director/stale_file_killer'
require 'fakefs/spec_helpers'

describe Bosh::Director::StaleFileKiller do
  describe '#kill' do
    include FakeFS::SpecHelpers
    let(:dir) { '/some/dir' }
    let(:old_file_path) { File.join(dir, 'over_one_hour') }
    let(:young_file_path) { File.join(dir, 'under_one_hour') }

    subject(:killer) { described_class.new(dir) }
    before do
      FileUtils.mkdir_p(dir)
      FileUtils.touch(old_file_path)
      # stupid fakefs doesnt respect mtime
      File.utime(Time.now - 3700, Time.now - 3700, old_file_path)
      FileUtils.touch(young_file_path, mtime: Time.now)
    end

    it 'removes all file last modified over 1 hour ago' do
      killer.kill
      expect(File).not_to exist(old_file_path)
    end

    it 'keeps files that were modified within an hour' do
      killer.kill
      expect(File).to exist(young_file_path)
    end
  end
end
