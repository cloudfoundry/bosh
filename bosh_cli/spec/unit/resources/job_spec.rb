require 'spec_helper'

describe Bosh::Cli::Resources::Job, 'dev build' do
  subject(:job) do
    Bosh::Cli::Resources::Job.new(release_source.join(base), release_source.path, made_packages)
  end

  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
  let(:base) { 'jobs/foo-job' }
  let(:name) { 'foo-job' }
  let(:spec) do
    {
      'name' => name,
      'packages' => spec_packages,
      'templates' => spec_templates,
    }
  end
  let(:made_packages) { ['foo', 'bar'] }
  let(:file_templates) { ['a.conf', 'b.yml'] }
  let(:spec_packages) { ['foo', 'bar'] }
  let(:spec_templates) { self_zip('a.conf', 'b.yml') }

  before do
    release_source.add_file(base, 'spec', spec.to_yaml)
    release_source.add_file(base, 'monit')
    release_source.add_files("#{base}/templates", file_templates)
  end

  after do
    release_source.cleanup
  end

  describe '.discover' do
    before do
      release_source.add_dir(base)
      release_source.add_dir('jobs/job_two')
    end

    it 'returns an Array of Job instances' do
      jobs = Bosh::Cli::Resources::Job.discover(release_source.path, made_packages)
      expect(jobs).to be_a(Array)
      expect(jobs[0]).to be_a(Bosh::Cli::Resources::Job)
      expect(jobs[1]).to be_a(Bosh::Cli::Resources::Job)
    end
  end

  describe '#initialize' do
    it 'sets the Job base directory' do
      expect(job.job_base).to be_a(Pathname)
      expect(job.job_base.to_s).to eq(release_source.join(base))
    end

    it 'sets the Job name' do
      expect(job.name).to eq('foo-job')
    end
  end

  describe '#spec' do
    it 'matches the Job spec file' do
      expect(job.spec).to eq(spec)
    end

    context 'when the spec file is missing' do
      before do
        release_source.remove_file(base, 'spec')
      end

      it 'raises' do
        expect { job.spec }.to raise_error(Bosh::Cli::InvalidJob, 'Job spec is missing')
      end
    end
  end

  describe '#validate!' do
    context 'when the Job name is nil' do
      let(:name) { nil }

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          'Job name is missing')
      end
    end

    context 'when the Job name is blank' do
      let(:name) { '' }

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          'Job name is missing')
      end
    end

    context 'when the Job name is not a valid BOSH identifier' do
      let(:name) { 'has space' }

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "'#{name}' is not a valid BOSH identifier")
      end
    end

    context 'when templates are not specified' do
      let(:spec) do
        {
          'name' => name,
          'packages' => spec_packages
        }
      end

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "Incorrect templates section in '#{name}' job spec (Hash expected, NilClass given)")
      end
    end

    context 'when templates on the filesystem are not found in the spec' do
      let(:spec_templates) { self_zip('a.conf') }

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "There are unused template files for job '#{name}': b.yml")
      end
    end

    context 'when templates in the spec are not found on the filesystem' do
      let(:spec_templates) { self_zip('a.conf', 'b.yml', 'c.conf') }

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "Some template files required by '#{name}' job are missing: c.conf")
      end
    end

    context 'when packages in the spec where not "made"' do
      let(:made_packages) { ['foo'] }

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "Some packages required by '#{name}' job are missing: bar")
      end
    end

    context 'when properties are not specified' do
      let(:spec) do
        {
          'name' => name,
          'packages' => spec_packages,
          'templates' => spec_templates
        }
      end

      it 'does not raise' do
        expect { job.validate! }.to_not raise_error
      end
    end

    context 'when properties are specified as something other than key-value pairs' do
      let(:spec) do
        {
          'name' => name,
          'packages' => spec_packages,
          'templates' => spec_templates,
          'properties' => 'bogus'
        }
      end

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "Incorrect properties section in '#{name}' job spec (Hash expected, String given)")
      end
    end

    context 'when properties are specified' do
      let(:properties) { {'foo' => 'bar'} }
      let(:spec) do
        {
          'name' => name,
          'packages' => spec_packages,
          'templates' => spec_templates,
          'properties' => properties
        }
      end

      it 'returns properties' do
        expect(job.properties).to eq(properties)
      end
    end

    context 'when no monit file is found on the filesystem' do
      before do
        release_source.remove_file(base, 'monit')
      end

      it 'raises' do
        expect { job.validate! }.to raise_error(Bosh::Cli::InvalidJob,
          "Cannot find monit file for '#{name}'")
      end
    end
  end

  describe '#files' do
    let(:archive_dir) { release_source.path }
    let(:blobstore) { double('blobstore') }
    let(:release_options) { {dry_run: false, final: false } }

    it 'includes a spec entry' do
      expect(job.files).to include([release_source.join(base, 'spec'), 'job.MF'])
    end

    it 'includes template file entries' do
      expect(job.files).to include([release_source.join(base, 'templates', 'a.conf'), 'templates/a.conf'])
      expect(job.files).to include([release_source.join(base, 'templates', 'b.yml'), 'templates/b.yml'])
    end

    it 'includes monit file entries' do
      expect(job.files).to include([release_source.join(base, 'monit'), 'monit'])
    end
  end

  def self_zip(*keys)
    keys.inject({}) do |map, key|
      map.merge({key => key})
    end
  end
end
