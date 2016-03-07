require 'open3'

describe 'postgres_ctl.erb' do
  context 'running postgres_db_backup.sh' do
    before do
      FileUtils.mkdir_p 'tmp/store/postgres'
      File.open('tmp/store/postgres/PG_VERSION', 'a+') {|f| f.write '9.0'}
      FileUtils.mkdir_p 'tmp/sys/run/postgres-9.4'
      FileUtils.touch 'tmp/store/postgres/postgresql.conf'
      FileUtils.mkdir_p 'tmp/jobs/postgres-9.4/bin'
      FileUtils.touch 'tmp/jobs/postgres-9.4/bin/postgres_db_upgrade.sh'
      File.chmod(0755, 'tmp/jobs/postgres-9.4/bin/postgres_db_upgrade.sh')
      ENV['BASE_DIR'] = 'tmp'
    end

    after do
      FileUtils.rm_rf 'tmp'
    end

    it 'should create a backup directory before migrating' do
      stdout, stderr, status = Open3.capture3('jobs/postgres-9.4/templates/postgres_db_backup.sh.erb')

      expect(status).to eq(0), "Expected to not receive an error. STDOUT: #{stdout} STDERR: #{stderr}"
      expect(Dir.exists?('tmp/store/postgres-previous'))
      expect(File.read('tmp/store/postgres-previous/PG_VERSION')).to eq('9.0')
    end
  end
end
