require 'spec_helper'

describe Bosh::Cli::JobBuilder do

  before { @release_dir = Dir.mktmpdir }

  def new_builder(name, packages = [], templates = { }, built_packages = [],
      create_spec = true, final = false, blobstore = double('blobstore'))
    # Workaround for Hash requirement
    if templates.is_a?(Array)
      templates = templates.inject({ }) { |h, e| h[e] = e; h }
    end

    spec = {
      'name' => name,
      'packages' => packages,
      'templates' => templates
    }
    add_spec(name) if create_spec

    Bosh::Cli::JobBuilder.new(spec, @release_dir,
                              final, blobstore, built_packages)
  end

  def add_file(job_name, file, contents = nil)
    job_dir = File.join(@release_dir, 'jobs', job_name)
    file_path = File.join(job_dir, file)
    FileUtils.mkdir_p(File.dirname(file_path))
    FileUtils.touch(file_path)
    if contents
      File.open(file_path, 'w') { |f| f.write(contents) }
    end
  end

  def add_spec(job_name)
    add_file(job_name, 'spec')
  end

  def add_monit(job_name, file='monit')
    add_file(job_name, file)
  end

  def add_templates(job_name, *files)
    job_template_path = File.join(@release_dir, 'jobs', job_name, 'templates')
    FileUtils.mkdir_p(job_template_path)

    files.each do |file|
      add_file(job_name, "templates/#{file}")
    end
  end

  def remove_templates(job_name, *files)
    job_template_path = File.join(@release_dir, 'jobs', job_name, 'templates')

    files.each do |file|
      FileUtils.rm_rf(File.join(job_template_path, file))
    end
  end

  it 'creates a new builder' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')
    builder = new_builder('foo', ['foo', 'bar', 'baz'],
                          ['a.conf', 'b.yml'], ['foo', 'bar', 'baz'])
    expect(builder.packages).to    eq(['foo', 'bar', 'baz'])
    expect(builder.templates).to     match_array(['a.conf', 'b.yml'])
    expect(builder.release_dir).to eq(@release_dir)
  end

  it 'has a fingerprint' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')
    builder = new_builder('foo', ['foo', 'bar'],
                          ['a.conf', 'b.yml'], ['foo', 'bar'])
    expect(builder.fingerprint).to eq('962d57a4f8bc4f48fd6282d8c4d94e4a744f155b')
  end

  it 'has a stable portable fingerprint' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')
    b1 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml'], ['foo', 'bar'])
    f1 = b1.fingerprint
    expect(b1.reload.fingerprint).to eq(f1)

    b2 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml'], ['foo', 'bar'])
    expect(b2.fingerprint).to eq(f1)
  end

  it 'changes fingerprint when new template file is added' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')

    b1 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml'], ['foo', 'bar'])
    f1 = b1.fingerprint

    add_templates('foo', 'baz')
    b2 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml', 'baz'], ['foo', 'bar'])
    expect(b2.fingerprint).not_to eq(f1)
  end

  it 'changes fingerprint when template files is changed' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')

    b1 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml'], ['foo', 'bar'])
    f1 = b1.fingerprint

    add_file('foo', 'templates/a.conf', 'bzz')
    expect(b1.reload.fingerprint).not_to eq(f1)
  end

  it 'changes fingerprint when new monit file is added' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo', 'foo.monit')

    b1 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml'], ['foo', 'bar'])
    f1 = b1.fingerprint

    add_monit('foo', 'bar.monit')
    b2 = new_builder('foo', ['foo', 'bar'],
                     ['a.conf', 'b.yml'], ['foo', 'bar'])
    expect(b2.fingerprint).not_to eq(f1)
  end

  it 'can read template file names from hash' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')
    builder = new_builder('foo', ['foo', 'bar', 'baz'],
                          { 'a.conf' => 1, 'b.yml' => 2 },
                          ['foo', 'bar', 'baz'])
    expect(builder.templates).to match_array(['a.conf', 'b.yml'])
  end

  it 'whines if name is blank' do
    expect {
      new_builder('')
    }.to raise_error(Bosh::Cli::InvalidJob, 'Job name is missing')
  end

  it 'whines on funny characters in name' do
    expect {
      new_builder('@#!', [])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "`@#!' is not a valid BOSH identifier")
  end

  it 'whines if some templates are missing' do
    add_templates('foo', 'a.conf', 'b.conf')

    expect {
      new_builder('foo', [], ['a.conf', 'b.conf', 'c.conf'])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Some template files required by 'foo' job " +
                           'are missing: c.conf')
  end

  it 'whines about extra packages' do
    add_templates('foo', 'a.conf', 'b.conf')

    expect {
      new_builder('foo', [], ['a.conf'], [])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "There are unused template files for job 'foo'" +
                           ': b.conf')
  end

  it 'whines if some packages are missing' do
    expect {
      new_builder('foo', ['foo', 'bar', 'baz', 'app42'], { }, ['foo', 'bar'])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Some packages required by 'foo' job are missing: " +
                           'baz, app42')
  end

  it 'whines if there is no spec file' do
    expect {
      new_builder('foo', ['foo', 'bar', 'baz', 'app42'], { },
                  ['foo', 'bar', 'baz', 'app42'], false)
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Cannot find spec file for 'foo'")
  end

  it 'whines if there is no monit file' do
    expect {
      add_templates('foo', 'a.conf', 'b.yml')
      new_builder('foo', ['foo', 'bar', 'baz', 'app42'],
                  ['a.conf', 'b.yml'], ['foo', 'bar', 'baz', 'app42'])
    }.to raise_error(Bosh::Cli::InvalidJob,
                         "Cannot find monit file for 'foo'")

    add_monit('foo')
    expect {
      new_builder('foo', ['foo', 'bar', 'baz', 'app42'],
                  ['a.conf', 'b.yml'], ['foo', 'bar', 'baz', 'app42'])
    }.not_to raise_error
  end

  it 'supports preparation script' do
    spec = {
      'name' => 'foo',
      'packages' => ['bar', 'baz'],
      'templates' => ['a.conf', 'b.yml']
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

    add_file('foo', 'prepare', script)
    script_path = File.join(@release_dir, 'jobs', 'foo', 'prepare')
    FileUtils.chmod(0755, script_path)
    Bosh::Cli::JobBuilder.run_prepare_script(script_path)

    builder = new_builder('foo', ['bar', 'baz'], ['a.conf', 'b.yml'],
                          ['foo', 'bar', 'baz', 'app42'], false)
    expect(builder.copy_files).to eq(4)

    Dir.chdir(builder.build_dir) do
      expect(File.directory?('templates')).to be(true)
      ['templates/a.conf', 'templates/b.yml'].each do |file|
        expect(File.file?(file)).to be(true)
      end
      expect(File.file?('job.MF')).to be(true)
      expect(File.read('job.MF')).to eq(File.read(
          File.join(@release_dir, 'jobs', 'foo', 'spec')))
      expect(File.exists?('monit')).to be(true)
      expect(File.exists?('prepare')).to be(false)
    end
  end

  it 'copies job files' do
    add_templates('foo', 'a.conf', 'b.yml')
    add_monit('foo')
    builder = new_builder('foo', ['foo', 'bar', 'baz', 'app42'],
                          ['a.conf', 'b.yml'], ['foo', 'bar', 'baz', 'app42'])

    expect(builder.copy_files).to eq(4)

    Dir.chdir(builder.build_dir) do
      expect(File.directory?('templates')).to be(true)
      ['templates/a.conf', 'templates/b.yml'].each do |file|
        expect(File.file?(file)).to be(true)
      end
      expect(File.file?('job.MF')).to be(true)
      expect(File.read('job.MF')).to eq(File.read(
          File.join(@release_dir, 'jobs', 'foo', 'spec')))
      expect(File.exists?('monit')).to be(true)
    end
  end

  it 'generates tarball' do
    add_templates('foo', 'bar', 'baz')
    add_monit('foo')

    builder = new_builder('foo', ['p1', 'p2'], ['bar', 'baz'], ['p1', 'p2'])
    expect(builder.generate_tarball).to be(true)
  end

  it 'supports versioning' do
    add_templates('foo', 'bar', 'baz')
    add_monit('foo')

    builder = new_builder('foo', [], ['bar', 'baz'], [])

    v1_fingerprint = builder.fingerprint
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).
        to be(false)
    builder.build
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).
        to be(true)

    add_templates('foo', 'zb.yml')
    builder = new_builder('foo', [], ['bar', 'baz', 'zb.yml'], [])
    builder.build
    v2_fingerprint = builder.fingerprint

    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).
        to be(true)
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v2_fingerprint}.tgz")).
        to be(true)

    remove_templates('foo', 'zb.yml')

    builder = new_builder('foo', [], ['bar', 'baz'], [])
    builder.build
    expect(builder.version).to eq(v1_fingerprint)

    expect(builder.fingerprint).to eq(v1_fingerprint)
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).
        to be(true)
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v2_fingerprint}.tgz")).
        to be(true)
  end

  def add_version(index, storage, key, build, src_file_path)
    index.add_version(key, build)
    file_path = storage.put_file(key, src_file_path)
    build['sha1'] = Digest::SHA1.file(file_path).hexdigest
    index.update_version(key, build)
  end

  it 'can point to either dev or a final version of a job' do
    add_templates('foo', 'bar', 'baz')
    add_monit('foo')
    fingerprint = '44cf6c4f4976f482ec497dfe77e47d876a7a83a1'

    job_name = 'foo'
    final_storage_dir = File.join(@release_dir, '.final_builds', 'jobs', job_name)
    final_versions = Bosh::Cli::Versions::VersionsIndex.new(final_storage_dir)
    final_storage = Bosh::Cli::Versions::LocalVersionStorage.new(final_storage_dir)

    dev_storage_dir = File.join(@release_dir, '.dev_builds', 'jobs', job_name)
    dev_versions   = Bosh::Cli::Versions::VersionsIndex.new(dev_storage_dir)
    dev_storage = Bosh::Cli::Versions::LocalVersionStorage.new(dev_storage_dir)

    add_version(final_versions, final_storage,
      fingerprint,
      { 'version' => fingerprint, 'blobstore_id' => '12321' },
      get_tmp_file_path('payload'))

    add_version(dev_versions, dev_storage,
      fingerprint,
      { 'version' => fingerprint },
      get_tmp_file_path('dev_payload'))

    builder = new_builder(job_name, [], ['bar', 'baz'], [])

    expect(builder.fingerprint).to eq(fingerprint)

    builder.use_final_version
    expect(builder.version).to eq(fingerprint)
    expect(builder.tarball_path).to eq(File.join(
        @release_dir, '.final_builds', 'jobs', job_name, "#{fingerprint}.tgz"))

    builder.use_dev_version
    expect(builder.version).to eq(fingerprint)
    expect(builder.tarball_path).to eq(File.join(
        @release_dir, '.dev_builds', 'jobs', job_name, "#{fingerprint}.tgz"))
  end

  it 'bumps major dev version in sync with final version' do
    add_templates('foo', 'bar', 'baz')
    add_monit('foo')

    builder = new_builder('foo', [], ['bar', 'baz'], [])
    builder.build

    expect(builder.version).to eq(builder.fingerprint)

    blobstore = double('blobstore')
    expect(blobstore).to receive(:create).and_return('object_id')
    final_builder = new_builder('foo', [], ['bar', 'baz'], [],
                                true, true, blobstore)
    final_builder.build

    expect(final_builder.version).to eq(final_builder.fingerprint)

    add_templates('foo', 'bzz')
    builder2 = new_builder('foo', [], ['bar', 'baz', 'bzz'], [])
    builder2.build
    expect(builder2.version).to eq(builder2.fingerprint)
  end

  it 'allows template subdirectories' do
    add_templates('foo', 'foo/bar', 'bar/baz')
    add_monit('foo')

    blobstore = double('blobstore')
    builder = new_builder('foo', [], ['foo/bar', 'bar/baz'],
                          [], true, false, blobstore)
    builder.build

    Dir.chdir(builder.build_dir) do
      expect(File.directory?('templates')).to be(true)
      ['templates/foo/bar', 'templates/bar/baz'].each do |file|
        expect(File.file?(file)).to be(true)
      end
    end
  end

  it 'supports dry run' do
    add_templates('foo', 'bar', 'baz')
    add_monit('foo')

    builder = new_builder('foo', [], ['bar', 'baz'], [])
    builder.dry_run = true
    builder.build
    v1_fingerprint = builder.fingerprint

    expect(builder.version).to eq(v1_fingerprint)
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).
        to be(false)

    builder.dry_run = false
    builder.reload.build
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).
        to be(true)

    blobstore = double('blobstore')
    expect(blobstore).not_to receive(:create)
    final_builder = new_builder('foo', [], ['bar', 'baz'], [],
                                true, true, blobstore)
    final_builder.dry_run = true
    final_builder.build

    # Shouldn't be promoted during dry run:
    expect(final_builder.version).to eq(v1_fingerprint)
    expect(File.exists?(@release_dir + "/.final_builds/jobs/foo/#{v1_fingerprint}.tgz")).to be(false)

    add_templates('foo', 'bzz')
    builder2 = new_builder('foo', [], ['bar', 'baz', 'bzz'], [])
    builder2.dry_run = true
    builder2.build
    v2_fingerprint = builder2.fingerprint
    expect(builder2.version).to eq(v2_fingerprint)

    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v1_fingerprint}.tgz")).to be(true)
    expect(File.exists?(@release_dir + "/.dev_builds/jobs/foo/#{v2_fingerprint}.tgz")).to be(false)
  end

end
