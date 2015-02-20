require 'spec_helper'
require 'tmpdir'

describe Bosh::Release::Compiler do
  before :all do
    @base_dir = Dir.mktmpdir
    @blobstore_path = File.join(@base_dir, 'blob_cache')
    FileUtils.mkdir(@blobstore_path)
  end

  let(:options) {
    {
      'blobstore_options' => {'blobstore_path' => @blobstore_path},
      'blobstore_provider' => 'local',
      'base_dir' => @base_dir,
      'logfile' => '/tmp/spec.log',
      'manifest' => spec_asset(manifest),
      'release' => spec_asset(release_tar),
      'apply_spec' => File.join(@base_dir, 'micro/apply_spec.yml'),
      :cpi => 'vsphere',
      :job => 'micro'
    }
  }

  let(:manifest) { 'micro_bosh/micro_bosh.yml' }
  let(:release_tar) { 'micro_bosh/micro_bosh.tgz' }

  after :all do
    FileUtils.rm_rf(@base_dir)
  end

  context 'when' do
    let(:compiler) { Bosh::Release::Compiler.new(options) }

    let(:test_agent) do
      agent = double(:agent)
      allow(agent).to receive(:ping)
      allow(agent).to receive(:run_task).and_return(result)
      agent
    end

    let(:result) { {'result' => {'blobstore_id' => 'blah', 'sha1' => 'blah'}} }

    before do
      expect(Bosh::Agent::Client).to receive(:create).and_return(test_agent)
    end

    it 'should compile packages according to the manifest' do
      allow(test_agent).to receive(:run_task).with(:compile_package, kind_of(String), 'sha1',
                                      /(ruby|nats|redis|libpq|postgres|blobstore|nginx|director|health_monitor)/,
                                      kind_of(String), kind_of(Hash)).and_return(result)
      expect(compiler.compile).to include('director')
    end

    it 'writes the apply spec as json if the json option is set' do
      compiler = Bosh::Release::Compiler.new(options.merge({json: true}))
      compiler.compile

      file = File.open(compiler.apply_spec_json)
      contents = file.read

      apply_spec_hash = JSON.parse(contents)
      expect(apply_spec_hash["deployment"]).to eq("micro")
      expect(compiler.apply_spec_json).to match(/json\z/)
    end

    context 'when job uses job collocation' do
      let(:manifest) { 'micro_bosh_collo/micro_bosh_collo.yml' }
      let(:release_tar) { 'micro_bosh_collo/micro_bosh_collo.tgz' }

      xit 'should add collocated jobs in apply spec' do
        compiler.compile
        spec = Psych.load_file(compiler.apply_spec)

        spec_jobs = spec['job']['templates']
        expect(spec_jobs.size).to eq(3)
        expect(spec_jobs[0]['name']).to eq('nats')
        expect(spec_jobs[1]['name']).to eq('redis')
        expect(spec_jobs[2]['name']).to eq('postgres')
      end
    end

    context 'when job does NOT use job collocation' do
      it 'should put only this job in apply spec' do
        compiler.compile
        spec =Psych.load_file(compiler.apply_spec)
        expect(spec['job']['templates'].size).to eq(1)

        micro_job_spec = spec['job']['templates'][0]
        expect(micro_job_spec['name']).to eq('micro')
        expect(micro_job_spec['version']).to eq('0.9-dev')
        expect(micro_job_spec['sha1']).to eq('ab62ca83016af6ddd5b24d535e339ee193bc7168')
        expect(micro_job_spec['blobstore_id']).to match(/[a-z\d-]/)
      end
    end

    it 'should call agent start after applying custom properties' do
      expect(test_agent).to receive(:run_task).with(:stop)
      expect(test_agent).to receive(:run_task).with(:apply, kind_of(Hash))
      expect(test_agent).to receive(:run_task).with(:start)
      compiler.apply
    end
  end

  it 'should compile packages for a specified job' do
    options[:job] = 'micro_aws'
    @compiler = Bosh::Release::Compiler.new(options)
    test_agent = double(:agent)
    allow(test_agent).to receive(:ping)
    digester = double('Digest::SHA1')
    allow(digester).to receive_messages(hexdigest: 'fake-sha1')
    allow(Digest::SHA1).to receive(:file).and_return(digester)
    result = {'result' => {'blobstore_id' => 'blah', 'sha1' => 'blah'}}
    allow(test_agent).to receive(:run_task).with(:compile_package, kind_of(String), 'fake-sha1',
                                    /(ruby|nats|redis|libpq|postgres|blobstore|nginx|director|health_monitor|aws_registry)/,
                                    kind_of(String), kind_of(Hash)).and_return(result)
    expect(Bosh::Agent::Client).to receive(:create).and_return(test_agent)
    expect(@compiler.compile).to include('aws_registry')
  end

  it 'should respect spec properties if job properties are empty' do
    spec_properties = {
      'foo' => {'bar1' => 'original'}
    }
    job_properties = {}

    @compiler = Bosh::Release::Compiler.new(options)
    @compiler.add_default_properties(spec_properties, job_properties)
    expect(spec_properties).to eq(spec_properties)
  end

  it 'should add default job properties to spec properties' do
    spec_properties = {
      'foo' => {'bar1' => 'original'}
    }

    job_properties = {
      'foo.bar1' => {'default' => 'notreplaced'},
      'foo.bar2' => {'default' => 'added'},
      'bar.vtrue' => {'default' => true},
      'bar.vfalse' => {'default' => false}
    }

    @compiler = Bosh::Release::Compiler.new(options)
    @compiler.add_default_properties(spec_properties, job_properties)
    expect(spec_properties).to eq({'foo' => {'bar1' => 'original',
                                         'bar2' => 'added'},
                               'bar' => {'vtrue' => true,
                                         'vfalse' => false}
                              })
  end

end
