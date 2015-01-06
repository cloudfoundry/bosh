require 'spec_helper'

describe Bosh::Director::DbBackup::Adapter::Sqlite do

  describe 'export' do
    let(:database) { 'director.db' }
    let(:path) { 'path to database backup' }
    subject { described_class.new('database' => database) }

    it 'exports the database to a file' do
      expect(FileUtils).to receive(:cp).with(database, path)

      subject.export(path)
    end
  end
end