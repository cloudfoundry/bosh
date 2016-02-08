require 'open3'

describe 'postgres_ctl.erb' do
  let(:postgres_upgrade_sh) { File.join(File.dirname(__FILE__), '../jobs/postgres/templates/postgres_upgrade.sh') }

  context 'running postgres_upgrade.sh' do
    before do
      FileUtils.mkdir_p 'tmp/store/postgres'
      FileUtils.mkdir_p 'tmp/sys/run/postgres'
      FileUtils.touch 'tmp/store/postgres/postgresql.conf'
      FileUtils.mkdir_p 'tmp/packages/postgres-9.4.5/bin'
      FileUtils.touch 'tmp/packages/postgres-9.4.5/bin/pg_upgrade'
      File.chmod(777, 'tmp/packages/postgres-9.4.5/bin/pg_upgrade')
      ENV['BASE_DIR'] = 'tmp'
    end

    after do
      FileUtils.rm_rf 'tmp'
    end

    it 'should create a backup directory before migrating' do
      _, _, status = Open3.capture3('jobs/postgres/templates/postgres_upgrade.sh.erb')

      expect(status).to eq(0)
      expect(Dir.exists?('tmp/store/postgres'))
      expect(Dir.exists?('tmp/store/postgres-9.4.5'))
    end
  end
end
