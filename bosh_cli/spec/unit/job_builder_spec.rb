require 'spec_helper'

describe Bosh::Cli::JobBuilder do
  subject(:builder) { make_builder(job_name, packages, templates, built_packages) }

  let(:release_dir) { Support::FileHelpers::ReleaseDirectory.new }
  let(:job_name) { 'foo-job' }
  let(:packages) { ['foo', 'bar'] }
  let(:templates) { ['a.conf', 'b.yml'] }
  let(:built_packages) { ['foo', 'bar'] }
  let(:blobstore) { double('blobstore') }
  let(:reference_fingerprint) do
    add_templates('reference-job', 'a.conf', 'b.yml')
    add_monit('reference-job')
    builder = make_builder('reference-job', ['foo', 'bar'], ['a.conf', 'b.yml'], ['foo', 'bar'])
    builder.fingerprint
  end

  before do
    add_templates(job_name, *templates)
    add_monit(job_name)
  end

  after { release_dir.cleanup }

  def make_builder(name, packages = [], template_names = [], built_packages = [], create_spec = true, final = false)
    spec = {
      'name' => name,
      'packages' => packages,
      'templates' => template_names.inject({ }) { |h, e| h[e] = e; h }
    }

    add_job_file(name, 'spec') if create_spec

    Bosh::Cli::JobBuilder.new(spec, release_dir.path,
                              final, blobstore, built_packages)
  end

  def add_job_file(job_name, file, contents = nil)
    release_dir.add_file("jobs/#{job_name}", file, contents)
  end

  def remove_job_file(job_name, file)
    release_dir.remove_file("jobs/#{job_name}", file)
  end

  def add_monit(job_name, file = 'monit')
    add_job_file(job_name, file)
  end

  def add_templates(job_name, *files)
    job_template_path = release_dir.join('jobs', job_name, 'templates')
    FileUtils.mkdir_p(job_template_path)

    files.each do |file|
      add_job_file(job_name, "templates/#{file}")
    end
  end

  def remove_templates(job_name, *files)
    release_dir.remove_files("jobs/#{job_name}/templates", files)
  end

  it 'creates a new builder' do
    expect(builder.packages).to eq(packages)
    expect(builder.templates).to match_array(templates)
    expect(builder.release_dir).to eq(release_dir.path)
  end

  describe 'the fingerprint' do
    subject(:fingerprint) { builder.fingerprint }

    it 'has a fingerprint' do
      expect(fingerprint).to eq('962d57a4f8bc4f48fd6282d8c4d94e4a744f155b')
    end

    it 'is stable and portable' do
      expect(fingerprint).to eq(reference_fingerprint)
    end

    context 'when templates differ' do
      let(:templates) { ['a.conf', 'b.yml', 'baz'] }
      before { add_templates(job_name, 'baz') }

      it 'is a different fingerprint' do
        expect(fingerprint).not_to eq(reference_fingerprint)
      end
    end

    context 'when template contents differ' do
      before { add_job_file(job_name, 'templates/a.conf', 'bzz') }

      it 'is a different fingerprint' do
        expect(fingerprint).not_to eq(reference_fingerprint)
      end
    end

    context 'when the monit file differs' do
      before { add_monit(job_name, 'bar.monit') }

      it 'is a different fingerprint' do
        expect(fingerprint).not_to eq(reference_fingerprint)
      end
    end
  end

  it 'whines if name is blank' do
    expect {
      make_builder('')
    }.to raise_error(Bosh::Cli::InvalidJob, 'Job name is missing')
  end

  it 'whines on funny characters in name' do
    expect {
      make_builder('@#!', [])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "`@#!' is not a valid BOSH identifier")
  end

  it 'whines if some templates are missing' do
    add_templates(job_name, 'a.conf', 'b.conf')

    expect {
      make_builder(job_name, [], ['a.conf', 'b.conf', 'c.conf'])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Some template files required by '#{job_name}' job " +
                           'are missing: c.conf')
  end

  it 'whines about extra templates' do
    expect {
      make_builder(job_name, [], ['a.conf'], [])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "There are unused template files for job '#{job_name}'" +
                           ': b.yml')
  end

  it 'whines if some packages are missing' do
    expect {
      make_builder(job_name, ['foo', 'bar', 'baz', 'app42'], { }, ['foo', 'bar'])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Some packages required by '#{job_name}' job are missing: " +
                           'baz, app42')
  end

  it 'whines if there is no spec file' do
    expect {
      make_builder(job_name, ['foo', 'bar', 'baz', 'app42'], { },
                  ['foo', 'bar', 'baz', 'app42'], false)
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Cannot find spec file for '#{job_name}'")
  end

  it 'whines if there is no monit file' do
    remove_job_file(job_name, 'monit')
    expect {
      builder
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Cannot find monit file for '#{job_name}'")
  end

  it 'supports preparation script' do
    spec = {
      'name' => job_name,
      'packages' => packages,
      'templates' => templates
    }
    spec_yaml = Psych.dump(spec)

    script = <<-SCRIPT.gsub(/^\s*/, '')
      #!/bin/sh
      mkdir templates
      touch templates/a.conf
      touch templates/b.yml
      echo '#{spec_yaml}' > spec
      touch monit
    SCRIPT

    add_job_file(job_name, 'prepare', script)
    script_path = release_dir.join('jobs', job_name, 'prepare')
    FileUtils.chmod(0755, script_path)
    Bosh::Cli::JobBuilder.run_prepare_script(script_path)

    expect(builder.copy_files).to eq(4)

    Dir.chdir(builder.build_dir) do
      expect(File.directory?('templates')).to be(true)
      ['templates/a.conf', 'templates/b.yml'].each do |file|
        expect(File.file?(file)).to be(true)
      end
      expect(File.file?('job.MF')).to be(true)
      expect(File.read('job.MF')).to eq(File.read(
        release_dir.join('jobs', job_name, 'spec')))
      expect(File.exists?('monit')).to be(true)
      expect(File.exists?('prepare')).to be(false)
    end
  end

  it 'copies job files' do
    expect(builder.copy_files).to eq(4)

    Dir.chdir(builder.build_dir) do
      expect(File.directory?('templates')).to be(true)
      ['templates/a.conf', 'templates/b.yml'].each do |file|
        expect(File.file?(file)).to be(true)
      end
      expect(File.file?('job.MF')).to be(true)
      expect(File.read('job.MF')).to eq(File.read(
        release_dir.join('jobs', job_name, 'spec')))
      expect(File.exists?('monit')).to be(true)
    end
  end

  it 'generates tarball' do
    builder.build

    tarball_file = Pathname(builder.dev_builds_dir).join("#{builder.fingerprint}.tgz")
    expect(tarball_file).to exist
    expect(`tar tfz #{tarball_file}`.split(/\n/)).to contain_exactly(
        "./", "./job.MF", "./monit", "./templates/", "./templates/a.conf", "./templates/b.yml")
  end

  describe 'versioning' do
    before do
      add_templates(job_name, *templates)
      add_monit(job_name)
    end

    it 'supports versioning' do
      v1_fingerprint = make_builder(job_name, [], templates, []).build.fingerprint
      expect(release_dir).to have_file("/.dev_builds/jobs/#{job_name}/#{v1_fingerprint}.tgz")

      add_templates(job_name, 'zb.yml')
      v2_fingerprint = make_builder(job_name, [], templates + ['zb.yml'], []).build.fingerprint
      expect(release_dir).to have_file("/.dev_builds/jobs/#{job_name}/#{v1_fingerprint}.tgz")
      expect(release_dir).to have_file("/.dev_builds/jobs/#{job_name}/#{v2_fingerprint}.tgz")

      remove_templates(job_name, 'zb.yml')
      builder3 = make_builder(job_name, [], templates, []).build
      expect(builder3.version).to eq(v1_fingerprint)
      expect(builder3.fingerprint).to eq(v1_fingerprint)
    end

    it "doesn't create a tarball for the version until you call #build" do
      builder1 = make_builder(job_name, [], templates, [])

      v1_fingerprint = builder1.fingerprint
      expect(release_dir).to_not have_file("/.dev_builds/jobs/#{job_name}/#{v1_fingerprint}.tgz")
      builder1.build
      expect(release_dir).to have_file("/.dev_builds/jobs/#{job_name}/#{v1_fingerprint}.tgz")
    end
  end

  it 'can point to either dev or a final version of a job' do
    fingerprint = '962d57a4f8bc4f48fd6282d8c4d94e4a744f155b'

    release_dir.add_version(fingerprint, ".final_builds/jobs/#{job_name}", 'payload',
      { 'version' => fingerprint, 'blobstore_id' => '12321' })

    release_dir.add_version(fingerprint, ".dev_builds/jobs/#{job_name}", 'dev_payload',
      { 'version' => fingerprint })

    builder = make_builder(job_name, [], templates, [])

    expect(builder.fingerprint).to eq(fingerprint)

    builder.use_final_version
    expect(builder.version).to eq(fingerprint)
    expect(builder.tarball_path).to eq(release_dir.join(
      '.final_builds', 'jobs', job_name, "#{fingerprint}.tgz"))

    builder.use_dev_version
    expect(builder.version).to eq(fingerprint)
    expect(builder.tarball_path).to eq(release_dir.join(
      '.dev_builds', 'jobs', job_name, "#{fingerprint}.tgz"))
  end

  it 'bumps major dev version in sync with final version' do
    builder = make_builder(job_name, [], templates, [])
    builder.build

    expect(builder.version).to eq(builder.fingerprint)

    expect(blobstore).to receive(:create).and_return('object_id')
    final_builder = make_builder(job_name, [], templates, [], true, true)
    final_builder.build

    expect(final_builder.version).to eq(final_builder.fingerprint)

    add_templates(job_name, 'bzz')
    builder2 = make_builder(job_name, [], templates + ['bzz'], [])
    builder2.build
    expect(builder2.version).to eq(builder2.fingerprint)
  end

  context 'when templates are in subdirectories' do
    let(:templates) { ['foo/bar', 'bar/baz'] }

    it 'allows template subdirectories' do
      add_templates(job_name, *templates)
      add_monit(job_name)

      builder = make_builder(job_name, [], templates, [], true, false)
      builder.build

      Dir.chdir(builder.build_dir) do
        expect(File.directory?('templates')).to be(true)
        ['templates/foo/bar', 'templates/bar/baz'].each do |file|
          expect(File.file?(file)).to be(true)
        end
      end
    end
  end

  describe 'dry_run option' do
    context 'when true' do
      before do
        builder.dry_run = true
      end

      it 'does not create an output archive' do
        builder.build
        expect(release_dir).to_not have_file("/.dev_builds/jobs/#{job_name}/#{builder.fingerprint}.tgz")
      end

      it 'does not affect the fingerprint' do
        builder.build
        expect(builder.fingerprint).to eq(reference_fingerprint)
      end

      it 'does not interact with the blobstore even when release is final' do
        expect(blobstore).not_to receive(:create)
        builder = make_builder(job_name, [], templates, [], true, true)
        builder.dry_run = true
        builder.build
      end
    end

    context 'when false' do
      before do
        builder.dry_run = false
      end

      it 'creates an output archive' do
        builder.build
        expect(release_dir).to have_file("/.dev_builds/jobs/#{job_name}/#{builder.fingerprint}.tgz")
      end

      it 'does not affect the fingerprint' do
        builder.build
        expect(builder.fingerprint).to eq(reference_fingerprint)
      end

      it 'does interact with the blobstore when release is final' do
        expect(blobstore).to receive(:create)
        builder = make_builder(job_name, [], templates, [], true, true)
        builder.dry_run = false
        builder.build
      end
    end
  end
end
