require 'spec_helper'

describe Bosh::WardenCloud::Cloud do
  let(:image_path) { asset('stemcell-warden-test.tgz') }
  let(:bad_image_path) { asset('stemcell-not-existed.tgz') }

  before(:each) do
    [:connect, :disconnect].each do |op|
      Warden::Client.any_instance.stub(op) do
        # no-op
      end
    end
    @logger = Bosh::Clouds::Config.logger
    @disk_root = Dir.mktmpdir('warden-cpi-disk')
    @stemcell_root = Dir.mktmpdir('warden-cpi-stemcell')
    options = {
        'disk' => {
            'root' => @disk_root,
            'fs' => 'ext4',
        },
        'stemcell' => {
            'root' => @stemcell_root,
        },
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)

  end

  after(:each) { FileUtils.rm_rf @stemcell_root }

  context 'create_stemcell' do
    it 'can create stemcell' do
      mock_sh('tar -C', true)
      stemcell_id = @cloud.create_stemcell(image_path, nil)
      Dir.chdir(@stemcell_root) do
        Dir.glob('*').should have(1).items
        Dir.glob('*').should include(stemcell_id)
      end
    end

    it 'should raise error with bad image path' do
      Bosh::WardenCloud::Cloud.any_instance.stub(:sudo) {}
      expect {
        @cloud.create_stemcell(bad_image_path, nil)
      }.to raise_error
    end

    it 'should clean up after an error is raised' do
      Bosh::Exec.stub(:sh) do |cmd|
        `#{cmd}`
        raise 'error'
      end

      Dir.chdir(@stemcell_root) do
        Dir.glob('*').should be_empty
        mock_sh('rm -rf', true)
        expect {
          @cloud.create_stemcell(image_path, nil)
        }.to raise_error

      end
    end
  end

  context 'delete_stemcell' do
    it 'can delete stemcell' do
      Dir.chdir(@stemcell_root) do
        mock_sh('tar -C', true)
        stemcell_id = @cloud.create_stemcell(image_path, nil)

        Dir.glob('*').should have(1).items
        Dir.glob('*').should include(stemcell_id)

        mock_sh('rm -rf', true)
        ret = @cloud.delete_stemcell(stemcell_id)

        ret.should be_nil
      end
    end
  end
end
