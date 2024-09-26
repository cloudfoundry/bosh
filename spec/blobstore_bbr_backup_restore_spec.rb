require 'spec_helper'

RSpec.describe 'blobstore' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(RELEASE_ROOT) }
  let(:job) { release.job('blobstore') }
  let(:rendered) { template.render(properties) }
  let(:tempfile) { Tempfile.new('bbr_backup') }
  let(:tmpdir) { Dir.mktmpdir }
  let(:properties) { {} }

  after do
    File.unlink(tempfile.path)
    FileUtils.remove_entry(tmpdir)
  end

  describe 'bin/bbr/backup' do
    let(:template) { job.template('bin/bbr/backup') }

    context 'blobstore.bbr.enabled = false' do
      let(:properties) do
        { 'blobstore' => { 'bbr' => { 'enabled' => false } } }
      end

      it 'logs that it skipped and does not backup the blobstore' do
        tempfile.write(rendered)
        tempfile.close

        File.chmod(0o755, tempfile.path)

        output = `ARTIFACT_DIRECTORY=/#{tmpdir} bash #{tempfile.path} 2>&1`
        expect(output).to eq "job property 'blobstore.bbr.enabled' is disabled\n"
      end
    end
  end

  describe 'bin/bbr/restore' do
    let(:template) { job.template('bin/bbr/restore') }

    context 'blobstore.bbr.enabled = false' do
      let(:properties) do
        { 'blobstore' => { 'bbr' => { 'enabled' => false } } }
      end

      it 'logs that it skipped and does not restore the blobstore' do
        tempfile.write(rendered)
        tempfile.close
        File.chmod(0o755, tempfile.path)

        output = `bash #{tempfile.path} 2>&1`
        expect(output).to eq "restore skipped because job property 'blobstore.bbr.enabled' is disabled\n"
      end
    end

    context 'bbr is enabled but the backup artifact had bbr disabled' do
      it 'logs that it skipped and does not restore the blobstore' do
        tempfile.write(rendered)
        tempfile.close
        File.chmod(0o755, tempfile.path)

        File.open("#{tmpdir}/backup-skipped", 'w') { |w| w.write('fake-reason') }

        output = `ARTIFACT_DIRECTORY=/#{tmpdir} bash #{tempfile.path} 2>&1`
        expect(output).to eq "restore skipped: backup artifact says: fake-reason\n"
      end
    end
  end
end
