require 'spec_helper'
require 'blue-shell'

describe '#bosh-director-drain-workers', truncation: true do
  let(:tmpdir) { Dir.mktmpdir }
  let(:director_config_filename) { File.join(tmpdir, 'director_config.yml') }

  before { File.write(director_config_filename, YAML.dump(SpecHelper.director_config_hash)) }
  after { FileUtils.rm_rf(tmpdir) }

  before do
    skip('because SQLite fails with "SQLite3::BusyException: database is locked"') if ENV.fetch('DB', 'sqlite') == 'sqlite'

    Delayed::Worker.backend = :sequel

    Delayed::Job.enqueue Bosh::Director::Jobs::DBJob.new(Bosh::Director::Jobs::VmState, 123, {})
  end

  context 'when a job is running' do
    before do
      Delayed::Job.reserve(Delayed::Worker.new(queues: ['urgent']))
    end

    it 'reports no jobs running in normal queue' do
      stdout = `bundle exec bosh-director-drain-workers --report --queue normal -c #{director_config_filename}`
      expect(stdout.strip).to eq('0')
    end

    it 'reports jobs running in urgent queue' do
      stdout = `bundle exec bosh-director-drain-workers --report --queue urgent -c #{director_config_filename}`
      expect(stdout.strip).to eq('1')
    end

    it 'reports some jobs running' do
      stdout = `bundle exec bosh-director-drain-workers --report -c #{director_config_filename}`
      expect(stdout.strip).to eq('1')
    end
  end

  it 'reports no jobs running' do
    stdout = `bundle exec bosh-director-drain-workers --report -c #{director_config_filename}`
    expect(stdout.strip).to eq('0')
  end
end
