require 'spec_helper'
require 'bat/stemcell'
require 'fileutils'

describe Bat::Stemcell do
  subject(:stemcell) { Bat::Stemcell.new('STEMCELL_NAME', 'STEMCELL_NAME') }

  describe '.from_path' do
    include FakeFS::SpecHelpers

    let(:fake_tmpdir) { '/fake/tmpdir' }
    let(:stemcell_file_path) { '/fake/path/stemcell.tgz' }

    before do
      FileUtils.mkdir_p(fake_tmpdir)
      Dir.stub(:mktmpdir).and_yield(fake_tmpdir)
      FileUtils.mkdir_p(File.dirname(stemcell_file_path))
    end

    it 'expands the stemcell file with tar, read its manifest, and return a new stemcell' do
      Bat::Stemcell.should_receive(:sh).with("tar xzf #{stemcell_file_path} --directory=#{fake_tmpdir} stemcell.MF") do
        File.open(File.join(fake_tmpdir, 'stemcell.MF'), 'w') do |f|
          f.write(YAML.dump(
            'name' => 'cloudy-centos',
            'version' => '007',
            'cloud_properties' => { 'infrastructure' => 'CloudyPony' }
          ))
        end
      end

      stemcell_from_path = Bat::Stemcell.from_path(stemcell_file_path)
      expect(stemcell_from_path.name).to eq('cloudy-centos')
      expect(stemcell_from_path.version).to eq('007')
      expect(stemcell_from_path.cpi).to eq('CloudyPony')
      expect(stemcell_from_path.path).to eq(stemcell_file_path)
    end
  end

  describe '#initialize' do
    it 'sets name' do
      expect(Bat::Stemcell.new('NAME', nil).name).to eq('NAME')
    end

    it 'sets version' do
      expect(Bat::Stemcell.new(nil, 'VERSION').version).to eq('VERSION')
    end

    it 'sets cpi to nil' do
      expect(Bat::Stemcell.new('NOT_NIL', 'NOT_NIL').cpi).to eq(nil)
    end

    it 'sets path to nil' do
      expect(Bat::Stemcell.new('NOT_NIL', 'NOT_NIL').path).to eq(nil)
    end

    context 'with three arguments' do
      it 'sets cpi' do
        expect(Bat::Stemcell.new(nil, nil, 'CPI').cpi).to eq('CPI')
      end

      it 'sets path to nil' do
        expect(Bat::Stemcell.new('NOT_NIL', 'NOT_NIL').path).to eq(nil)
      end
    end

    context 'with four arguments' do
      it 'sets path' do
        expect(Bat::Stemcell.new(nil, nil, nil, '/fake/path/stemcell.tgz').path).to eq('/fake/path/stemcell.tgz')
      end
    end
  end

  describe '#supports_network_reconfiguration?' do
    {
      # Ruby agent (default)
      'bosh-custom-xen-ubuntu' => true,
      'bosh-custom-xen-centos' => true,

      # Ruby agent does not support prepare_configure_networks/configure_networks
      'bosh-vsphere-esxi-ubuntu' => false,
      'bosh-vcloud-esxi-ubuntu' => false,

      # Centos currently does not include open-vm-tools
      'bosh-vsphere-esxi-centos' => false,
      'bosh-vcloud-esxi-centos' => false,

      # Go agent
      'bosh-custom-xen-ubuntu-go_agent' => true,
      'bosh-custom-xen-centos-go_agent' => true,
      'bosh-vsphere-esxi-ubuntu-go_agent' => true,
      'bosh-vcloud-esxi-ubuntu-go_agent' => true,

      # Centos currently does not include open-vm-tools
      'bosh-vsphere-esxi-centos-go_agent' => false,
      'bosh-vcloud-esxi-centos-go_agent' => false,

      # Warden CPI does not support network reconfig
      'bosh-warden-boshlite-ubuntu-go_agent' => false,
      'bosh-warden-boshlite-centos-go_agent' => false,

    }.each do |stemcell_name, expected|
      it "returns #{expected} for #{stemcell_name}" do
        stemcell = Bat::Stemcell.new(stemcell_name, nil)
        expect(stemcell.supports_network_reconfiguration?).to be(expected)
      end
    end
  end

  describe '#to_s' do
    it 'returns "<name>-<version>"' do
      expect(stemcell.to_s).to eq('STEMCELL_NAME-STEMCELL_NAME')
    end
  end

  describe '#to_path' do
    context 'when path is not set' do
      it 'returns nil' do
        expect(stemcell.to_path).to eq(nil)
      end
    end

    context 'when path is set' do
      subject(:stemcell) { Bat::Stemcell.new(nil, nil, nil, '/fake/path/stemcell.tgz') }

      it 'returns #path' do
        expect(stemcell.to_path).to eq('/fake/path/stemcell.tgz')
      end
    end
  end
end
