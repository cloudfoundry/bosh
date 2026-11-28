require 'spec_helper'
require 'open3'

RSpec.describe 'postgres job migration to postgres-release' do
  let(:release) { Bosh::Common::Template::Test::ReleaseDir.new(RELEASE_ROOT) }
  let(:job) { release.job('postgres') }
  let(:properties) do
    {
      'postgres' => {
        'adapter' => 'postgres',
        'database' => 'bosh',
        'host' => '127.0.0.1',
        'listen_address' => '127.0.0.1',
        'password' => 'secret',
        'user' => 'postgres',
      },
    }
  end

  def expect_valid_bash(script)
    _, stderr, status = Open3.capture3('bash', '-n', stdin_data: script)
    expect(status).to be_success, stderr
  end

  describe 'bin/migrate-to-postgres-release' do
    subject(:rendered) { job.template('bin/migrate-to-postgres-release').render(properties) }

    it 'renders a valid bash script' do
      expect_valid_bash(rendered)
    end

    it 'moves the data into the postgres-release layout' do
      expect(rendered).to include('OLD_DATA_DIR=${PERSISTENT_DISK_DIR}/postgres-${MAJOR_VERSION}')
      expect(rendered).to include('VERSION_FILE=${PG_STORE_DIR}/POSTGRES_DATA_VERSION')
    end

    it 'records the migration before moving the data' do
      pending_write = rendered.index('write_state_file "${PENDING_FILE}"')
      move = rendered.index('mv "${OLD_DATA_DIR}" "${PG_STORE_DIR}/${target_name}"')

      expect(pending_write).not_to be_nil
      expect(pending_write).to be < move
    end

    it 'writes the state files atomically' do
      expect(rendered).to include('mv "${tmp_file}" "$1"')
    end

    it 'detects a rollback that was interrupted after moving the data back' do
      expect(rendered).to include('a rollback was interrupted and the data is back in ${OLD_DATA_DIR}')
    end

    it 'refuses to roll back once postgres-release has run on the data' do
      expect(rendered).to include('[ "$(checkpoint_location "${data_dir}")" = "${checkpoint}" ]')
    end
  end

  describe 'bin/pre-start' do
    subject(:rendered) { job.template('bin/pre-start').render(properties) }

    it 'renders a valid bash script' do
      expect_valid_bash(rendered)
    end

    it 'warns that the job is deprecated' do
      expect(rendered).to include('WARNING: The postgres job is deprecated')
    end

    it 'refuses to initialise an empty database after the data was migrated' do
      guard = rendered.index('.migrated-from-bosh-postgres-job')
      initdb = rendered.index('bin/initdb')

      expect(guard).not_to be_nil
      expect(guard).to be < initdb
    end

    it 'also refuses to initialise an empty database while a migration is interrupted' do
      guard = rendered.index('.migrating-from-bosh-postgres-job')
      initdb = rendered.index('bin/initdb')

      expect(guard).not_to be_nil
      expect(guard).to be < initdb
    end
  end
end
