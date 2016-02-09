require 'open3'

describe 'postgres_ctl.erb' do
  let(:postgres_upgrade_sh) { File.join(File.dirname(__FILE__), '../jobs/postgres/templates/postgres_upgrade.sh') }

  context 'running postgres_upgrade.sh' do
    before do
      FileUtils.mkdir_p 'tmp/store/postgres'
      File.open('tmp/store/postgres/PG_VERSION', 'a+') {|f| f.write '9.0'}
      FileUtils.mkdir_p 'tmp/sys/run/postgres'
      FileUtils.touch 'tmp/store/postgres/postgresql.conf'
      FileUtils.mkdir_p 'tmp/jobs/postgres/bin'
      FileUtils.touch 'tmp/jobs/postgres/bin/really_upgrade_postgres.sh'
      File.chmod(777, 'tmp/jobs/postgres/bin/really_upgrade_postgres.sh')
      ENV['BASE_DIR'] = 'tmp'
    end

    after do
      FileUtils.rm_rf 'tmp'
    end

    it 'should create a backup directory before migrating' do
      _, _, status = Open3.capture3('jobs/postgres/templates/postgres_upgrade.sh.erb')

      expect(status).to eq(0)
      expect(Dir.exists?('tmp/store/postgres-previous'))
      expect(File.read('tmp/store/postgres-previous/PG_VERSION')).to eq('9.0')
    end
  end
end
