# encoding: UTF-8

require 'spec_helper'

describe Bosh::Cli::BackupDestinationPath do
  let(:dest) { Bosh::Cli::BackupDestinationPath.new(director) }

  let(:epoch) { Time.now.to_i }
  let(:bosh_name) { 'bosh-name' }
  let(:bosh_status) { { 'name' => bosh_name } }
  let(:director) { double(Bosh::Cli::Client::Director, get_status: bosh_status) }

  let(:pwd) { Dir.pwd }

  around do |example|
    Timecop.freeze do
      example.run
    end
  end

  describe 'creating a backup path' do
    context 'if the user does not provide a path' do
      it 'uses the default backup name in the current directory' do
        expect(dest.create_from_path).to eq File.join(pwd, "bosh_backup_#{bosh_name}_#{epoch}.tgz")
      end
    end

    context 'if the user provides an existing directory' do
      it 'uses the passed in directory with the default name' do
        Dir.mktmpdir do |temp_dir|
          expect(dest.create_from_path(temp_dir)).to eq File.join(temp_dir, "bosh_backup_#{bosh_name}_#{epoch}.tgz")
        end
      end
    end

    context 'if the user provides a non-existent path' do
      context 'if they put a tarball extension on the end of the path' do
        context 'if the path ends in .tgz' do
          let(:dest_file) { 'backup.tgz' }

          it 'uses the passed in path' do
            Dir.mktmpdir do |temp_dir|
              dest_path = File.join(temp_dir, dest_file)
              expect(dest.create_from_path(dest_path)).to eq dest_path
            end
          end
        end

        context 'if the path ends in .tar.gz' do
          let(:dest_file) { 'backup.tar.gz' }

          it 'uses the passed in path' do
            Dir.mktmpdir do |temp_dir|
              dest_path = File.join(temp_dir, dest_file)
              expect(dest.create_from_path(dest_path)).to eq dest_path
            end
          end
        end
      end

      context 'if they do not put a tarball extension on the end of the path' do
        let(:dest_file) { 'backup' }

        it 'adds .tgz to the supplied path' do
          Dir.mktmpdir do |temp_dir|
            dest_path = File.join(temp_dir, dest_file)
            expect(dest.create_from_path(dest_path)).to eq "#{dest_path}.tgz"
          end
        end
      end
    end
  end
end