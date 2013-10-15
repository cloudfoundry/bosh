require 'spec_helper'

module Bosh::Deployer
  describe Helpers do
    include Helpers
    include FakeFS::SpecHelpers

    before do
      FileUtils.mkdir_p('/tmp/fake/path')
      FileUtils.touch('/tmp/fake/path/file')
    end

    describe 'strip_relative_path' do
      context 'relative to current path' do
        before do
          Dir.chdir('/tmp')
        end

        it 'strips present work directory off of path' do
          expect(strip_relative_path('/tmp/fake/path/file')).to eq('fake/path/file')
        end
      end

      context 'above current path' do
        before do
          FileUtils.mkdir_p('/tmp/fake/path/a/little/further/out')
          Dir.chdir('/tmp/fake/path/a/little/further/out')
        end
        it 'returns absolute path' do
          expect(strip_relative_path('/tmp/fake/path/file')).to eq('/tmp/fake/path/file')
        end
      end
    end
  end
end