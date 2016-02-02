require 'rspec'
require 'bosh/dev/postgres_version'

module Bosh::Dev
  describe PostgresVersion do
    describe 'release version' do
      it 'has same major and minor version with local postgres' do
        local_major_and_minor_version = PostgresVersion.local_version.split('.')[0..1]
        release_major_and_minor_version = PostgresVersion.release_version.split('.')[0..1]
        expect(local_major_and_minor_version).to eq(release_major_and_minor_version)
      end
    end
  end
end
