require 'spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Apply, dummy_infrastructure: true do
  let(:dummy_platform) { instance_double('Bosh::Agent::Platform::Linux::Adapter', update_logging: nil) }

  before do
    Bosh::Agent::Config.state = Bosh::Agent::State.new(Tempfile.new('state').path)

    Bosh::Agent::Config.blobstore_provider = 'simple'
    Bosh::Agent::Config.blobstore_options = {}
    Bosh::Agent::Config.stub(platform: dummy_platform)
    Bosh::Agent::Config.platform_name = 'dummy'

    FileUtils.mkdir_p(File.join(base_dir, 'monit'))
    Bosh::Agent::Monit.setup_monit_user

    # FIXME: use Dummy platform for tests
    system_root = Bosh::Agent::Config.system_root
    FileUtils.mkdir_p(File.join(system_root, 'etc', 'logrotate.d'))

    @httpclient = double('httpclient')
    HTTPClient.stub(:new).and_return(@httpclient)
  end

  context 'when it fails to write an ERB template' do
    let(:response) { double('response', status: 200) }
    let(:apply_data) do
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => {
          'name' => 'bubba',
          'template' => 'bubba',
          'blobstore_id' => 'some_blobstore_id',
          'version' => '77',
          'sha1' => Digest::SHA1.hexdigest(dummy_job_data) },
        'release' => { 'version' => '99' }
      }
    end
    subject(:apply_message) { Bosh::Agent::Message::Apply.new([apply_data]) }

    before do
      @httpclient.stub(:get).with('/resources/some_blobstore_id', {}, {}).and_yield(dummy_job_data).and_return(response)
    end

    it 'raises a useful error' do
      apply_message.stub(:apply_packages)
      expect {
        apply_message.apply
      }.to raise_error(Bosh::Agent::MessageHandlerError,
                       /Failed to install job 'bubba.bubba': failed to process configuration template 'thin.yml.erb': line 6, error:/)
    end
  end

  context 'when agent state does not have deployment set' do
    subject(:apply_message) { Bosh::Agent::Message::Apply.new([{ 'deployment' => 'foo' }]) }

    it 'sets deployment in agents state' do
      state = Bosh::Agent::Message::State.new
      state.stub(job_state: 'running')

      apply_message.apply

      expect(state.state['deployment']).to eq 'foo'
    end
  end

  describe 'packages' do
    let(:response) { double('response', status: 200) }
    let(:apply_data) do
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => {
          'name' => 'bubba',
          'template' => 'bubba',
          'blobstore_id' => 'some_blobstore_id',
          'version' => '77',
          'sha1' => 'deadbeef'
        },
        'release' => { 'version' => '99' },
        'networks' => { 'network_a' => { 'ip' => '11.0.0.1' } },
        'packages' => {
          'bubba' => {
            'name' => 'bubba',
            'version' => '2',
            'blobstore_id' => 'some_blobstore_id',
            'sha1' => Digest::SHA1.hexdigest(dummy_package_data)
          }
        }
      }
    end

    subject(:apply_message) { Bosh::Agent::Message::Apply.new([apply_data]) }

    before do
      @httpclient.stub(:get).with('/resources/some_blobstore_id', {}, {}).and_yield(dummy_package_data).and_return(response)
    end

    it 'installs packages' do
      apply_message.should_receive(:apply_job)

      job_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'bubba', '77', 'packages')
      FileUtils.mkdir_p(job_dir)

      apply_message.apply
    end
  end

  context 'when package GC happens (e.g. by applying 3 specs)' do
    let(:response) { double('response', status: 200) }
    let(:package_sha1) { Digest::SHA1.hexdigest(dummy_package_data) }

    let(:apply_data1) do
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => { 'name' => 'bubba', 'template' => 'bubba', 'blobstore_id' => 'some_blobstore_id', 'version' => '77', 'sha1' => 'deadbeef' },
        'release' => { 'version' => '99' },
        'networks' => { 'network_a' => { 'ip' => '11.0.0.1' } },
        'packages' =>
          { 'bubba0' => { 'name' => 'bubba0', 'version' => '2', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
            'bubba1' => { 'name' => 'bubba1', 'version' => '2', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
            'bubba2' => { 'name' => 'bubba2', 'version' => '2', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
            'bubba3' => { 'name' => 'bubba3', 'version' => '2', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
          },
      }
    end

    let(:apply_data2) do
      apply_data2 = apply_data1.dup
      apply_data2['packages'] ={
        'bubba3' => { 'name' => 'bubba3', 'version' => '3', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
        'bubba4' => { 'name' => 'bubba4', 'version' => '2', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
      }
      apply_data2
    end

    let(:apply_data3) do
      apply_data2.merge(
        'packages' => {
          'bubba4' => { 'name' => 'bubba3', 'version' => '2', 'blobstore_id' => 'some_blobstore_id', 'sha1' => package_sha1 },
        }
      )
    end

    def installed_packages(pkg_base)
      Dir["#{pkg_base}/*/*"]
    end

    def spec_package_paths(pkg_base, apply_spec)
      pkg_paths = []
      apply_spec['packages'].each do |k, v|
        pkg_paths << File.join(pkg_base, v['name'], v['version'])
      end
      pkg_paths
    end

    before do
      @httpclient.stub(:get).exactly(7).times.with('/resources/some_blobstore_id', {}, {}).and_yield(dummy_package_data).and_return(response)
    end

    it 'cleans up old packages' do
      job_dir = File.join(base_dir, 'data', 'jobs', 'bubba', '77', 'packages')
      FileUtils.mkdir_p(job_dir)
      pkg_base = File.join(base_dir, 'data', 'packages')

      # 1st apply - against empty state
      apply_message1 = Bosh::Agent::Message::Apply.new([apply_data1])
      apply_message1.stub(:apply_job)
      apply_message1.apply

      pkg_paths = spec_package_paths(pkg_base, apply_data1)
      pkg_paths.sort.should == installed_packages(pkg_base).sort

      # 2nd apply - package path list is the union of 1st and 2nd apply
      apply_message2 = Bosh::Agent::Message::Apply.new([apply_data2])
      apply_message2.stub(:apply_job)
      apply_message2.apply

      pkg_paths2 = spec_package_paths(pkg_base, apply_data2)
      check_package_paths = pkg_paths2 + pkg_paths

      check_package_paths.sort.should == installed_packages(pkg_base).sort

      # 3rd apply - package path list is the union of 2nd and 3rd apply (with 1st deploy cleaned up)
      apply_message3 = Bosh::Agent::Message::Apply.new([apply_data3])
      apply_message3.stub(:apply_job)
      apply_message3.apply

      pkg_paths3 = spec_package_paths(pkg_base, apply_data3)
      check_package_paths = pkg_paths3 + pkg_paths2

      check_package_paths.sort.should == installed_packages(pkg_base).sort
    end
  end

  describe 'jobs' do
    let(:response) { double('response', status: 200) }

    let(:apply_data) do
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => {
          'name' => 'bubba',
          'template' => 'bubba',
          'blobstore_id' => 'some_blobstore_id',
          'version' => '77',
          'sha1' => Digest::SHA1.hexdigest(dummy_job_data) },
        'release' => { 'version' => '99' },
        'networks' => { 'network_a' => { 'ip' => '11.0.0.1' } },
      }
    end

    subject(:apply_message) { Bosh::Agent::Message::Apply.new([apply_data]) }

    before do
      @httpclient.stub(:get).with('/resources/some_blobstore_id', {}, {}).and_yield(dummy_job_data).and_return(response)
    end

    it 'should install a job' do
      apply_message.stub(:apply_packages)

      apply_message.apply

      bin_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'bubba', '77', 'bin')
      expect(File.directory?(bin_dir)).to be(true)

      bin_file = File.join(bin_dir, 'my_sinatra_app')
      expect(File.executable?(bin_file)).to be(true)
    end
  end

  context 'one job with one monit file' do
    let(:response) { double('response', status: 200) }
    let(:job_data) { read_asset('hubba.tgz') }
    let(:apply_data) do
      job_sha1 = Digest::SHA1.hexdigest(job_data)
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => { 'name' => 'hubba', 'template' => 'hubba', 'blobstore_id' => 'some_blobstore_id', 'version' => '77', 'sha1' => job_sha1 },
        'release' => { 'version' => '99' },
        'networks' => { 'network_a' => { 'ip' => '11.0.0.1' } }
      }
    end

    subject(:apply_message) { Bosh::Agent::Message::Apply.new([apply_data]) }

    before do
      @httpclient.stub(:get).with('/resources/some_blobstore_id', {}, {}).and_yield(job_data).and_return(response)
    end

    it 'installs the job' do
      apply_message.stub(:apply_packages)
      apply_message.apply

      monitrc = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'hubba', '77', '0000_hubba.hubba_hubba.monitrc')
      expect(File.exist?(monitrc)).to be(true)
    end
  end

  context 'two jobs with two monit files' do
    let(:response) { double('response', status: 200) }
    let(:job_data) { read_asset('hubba.tgz') }
    let(:job2_data) { read_asset('hubba2.tgz') }
    let(:apply_data) do
      job_sha1 = Digest::SHA1.hexdigest(job_data)
      job2_sha1 = Digest::SHA1.hexdigest(job2_data)
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => { 'name' => 'hubba', 'templates' => [
          { 'name' => 'hubba', 'blobstore_id' => 'some_blobstore_id',
            'version' => '77', 'sha1' => job_sha1 },
          { 'name' => 'hubba2', 'blobstore_id' => 'some_blobstore_id2',
            'version' => '77', 'sha1' => job2_sha1 }] },
        'release' => { 'version' => '99' },
        'networks' => { 'network_a' => { 'ip' => '11.0.0.1' } },
      }
    end

    subject(:apply_message) { Bosh::Agent::Message::Apply.new([apply_data]) }

    before do
      @httpclient.stub(:get).with('/resources/some_blobstore_id', {}, {}).and_yield(job_data).and_return(response)
      @httpclient.stub(:get).with('/resources/some_blobstore_id2', {}, {}).and_yield(job2_data).and_return(response)
    end

    it 'installs the jobs' do
      apply_message.stub(:apply_packages)
      apply_message.apply

      monitrc1 = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'hubba', '77', '0001_hubba.hubba_hubba.monitrc')
      File.exist?(monitrc1).should == true

      monitrc2 = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'hubba2', '77', '0000_hubba.hubba2_hubba.monitrc')
      File.exist?(monitrc2).should == true
    end
  end

  context 'when a plan is created' do
    let(:response) { double('response', status: 200) }
    let(:job_data) { read_asset('hubba.tgz') }
    let(:apply_data) do
      job_sha1 = Digest::SHA1.hexdigest(job_data)
      {
        'configuration_hash' => 'bogus',
        'deployment' => 'foo',
        'job' => { 'name' => 'hubba', 'template' => 'hubba',
                   'blobstore_id' => 'some_blobstore_id', 'version' => '77',
                   'sha1' => job_sha1 },
        'release' => { 'version' => '99' },
        'networks' => { 'network_a' => { 'ip' => '11.0.0.1' } },
      }
    end

    subject(:apply_message) { Bosh::Agent::Message::Apply.new([apply_data]) }

    before do
      @httpclient.stub(:get).with('/resources/some_blobstore_id', {}, {}).and_yield(job_data).and_return(response)
    end

    it 'does not modify the spec' do
      apply_message.stub(:apply_packages)
      expect {
        apply_message.apply
      }.to_not change { apply_data }
    end
  end
end
