require 'spec_helper'
require 'bosh/dev/bulk_uploader'

describe Bosh::Dev::BulkUploader do
  include FakeFS::SpecHelpers

  let(:bucket_name) { 'fake-bucket' }
  let(:pipeline) { double(Bosh::Dev::Pipeline, bucket: bucket_name, fog_storage: fog_storage) }
  let(:src) { 'source_dir' }
  let(:dst) { 'dest_dir' }

  let(:fog_storage) do
    Fog::Storage.new(provider: 'AWS',
                     aws_access_key_id: 'access key',
                     aws_secret_access_key: 'secret key')
  end

  let(:files) do
    %w[
      foo/bar.txt
      foo/bar/baz.txt
    ]
  end

  subject { Bosh::Dev::BulkUploader.new(pipeline) }

  before do
    Fog.mock!

    fog_storage.directories.create(key: bucket_name)
    FileUtils.mkdir_p(src)

    Dir.chdir(src) do
      files.each do |path|
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w') { |f| f.write("Contents of #{path}") }
      end
    end

    ENV.stub(:to_hash).and_return({
                                    'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'access key',
                                    'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'secret key'
                                  })
  end

  describe 'upload_r' do

    it 'recursively uploads a directory into base_dir' do
      pipeline.should_receive(:create).with do |options|
        expect(options[:public]).to eq(true)

        case options[:key]
          when 'dest_dir/foo/bar.txt'
            expect(options[:body].read).to eq('Contents of foo/bar.txt')
          when 'dest_dir/foo/bar/baz.txt'
            expect(options[:body].read).to eq('Contents of foo/bar/baz.txt')
          else
            raise "unexpected key: #{options[:key]}"
        end
      end.exactly(2).times

      subject.upload_r(src, dst)
    end
  end
end
