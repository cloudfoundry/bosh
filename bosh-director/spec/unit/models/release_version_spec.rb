require 'spec_helper'

module Bosh::Director::Models
  describe ReleaseVersion do
    describe '#package_by_name' do
      let(:package) do
        Package.new(name: 'this-releases-package')
      end

      subject(:release_version) do
        release_version = ReleaseVersion.new
        release_version.packages << package
        release_version
      end

      context 'when the package is part of the release' do
        it 'returns the package object given its name' do
          expect(release_version.package_by_name('this-releases-package')).to eq(package)
        end
      end

      context 'when the package is not part of the release' do
        it 'blows up' do
          expect {
            release_version.package_by_name('another-releases-package')
          }.to raise_error 'key not found: "another-releases-package"'
        end
      end
    end
  end
end
