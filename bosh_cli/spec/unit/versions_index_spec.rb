require 'spec_helper'

describe Bosh::Cli::VersionsIndex do
  before :each do
    @dir = Dir.mktmpdir
    @index_file = File.join(@dir, 'index.yml')
    @index = Bosh::Cli::VersionsIndex.new(@dir)
  end

  after :each do
    FileUtils.rm_rf(@dir)
  end

  it 'only creates directory structure on writes to index' do
    expect(File).to_not exist(@index_file)
    expect(@index.version_exists?(1)).to be(false)
    expect(@index['deadbeef']).to be_nil
    expect(@index.versions).to be_empty
    expect(File).to_not exist(@index_file)

    @index.add_version('deadcafe',
                       { 'version' => 2 },
                       get_tmp_file_path('payload2'))
    expect(File).to exist(@index_file)
  end

  it 'chokes on malformed index file' do
    File.open(@index_file, 'w') { |f| f.write('deadbeef') }

    expect {
      @index = Bosh::Cli::VersionsIndex.new(@dir)
    }.to raise_error(Bosh::Cli::InvalidIndex,
                         'Invalid versions index data type, ' +
                           'String given, Hash expected')
  end

  it "doesn't choke on empty index file" do
    File.open(@index_file, 'w') { |f| f.write('') }
    @index = Bosh::Cli::VersionsIndex.new(@dir)
    expect(@index.versions).to be_empty
  end

  it 'can be used to add versioned payloads to index' do
    item1 = { 'a' => 1, 'b' => 2, 'version' => 1 }
    item2 = { 'a' => 3, 'b' => 4, 'version' => 2 }

    @index.add_version('deadbeef',
                       item1,
                       get_tmp_file_path('payload1'))
    @index.add_version('deadcafe',
                       item2,
                       get_tmp_file_path('payload2'))

    expect(@index['deadbeef']).to eq(item1.merge('sha1' => Digest::SHA1.hexdigest('payload1')))
    expect(@index['deadcafe']).to eq(item2.merge('sha1' => Digest::SHA1.hexdigest('payload2')))
    expect(@index.version_exists?(1)).to be(true)
    expect(@index.version_exists?(2)).to be(true)
    expect(@index.version_exists?(3)).to be(false)

    expect(@index.filename(1)).to eq(File.join(@dir, '1.tgz'))
    expect(@index.filename(2)).to eq(File.join(@dir, '2.tgz'))
  end

  it 'you shall not pass without version' do
    item_noversion = { 'a' => 1, 'b' => 2 }
    expect {
      @index.add_version('deadbeef', item_noversion, 'payload1')
    }.to raise_error(
      Bosh::Cli::InvalidIndex,
      'Cannot save index entry without knowing its version'
    )
  end

  it 'does not allow duplicate versions with different fingerprints' do
    item1 = { 'a' => 1, 'b' => 2, 'version' => '1.9-dev' }

    @index.add_version('deadbeef', item1, get_tmp_file_path('payload1'))

    expect {
      @index.add_version('deadcafe', item1, get_tmp_file_path('payload3'))
    }.to raise_error(
      "Trying to add duplicate version `1.9-dev' into index `#{File.join(@dir, 'index.yml')}'"
    )
  end

  it 'overwrites a payload with identical fingerprint' do
    item1 = { 'a' => 1, 'b' => 2, 'version' => '1.8-dev' }
    item2 = { 'b' => 2, 'c' => 3, 'version' => '1.9-dev' }

    @index.add_version('deadbeef', item1, get_tmp_file_path('payload1'))
    @index.add_version('deadbeef', item2, get_tmp_file_path('payload3'))
    expect(@index['deadbeef']).to eq(item2)
  end

  it 'supports finding entries by checksum' do
    item1 = { 'a' => 1, 'b' => 2, 'version' => 1 }
    item2 = { 'a' => 3, 'b' => 4, 'version' => 2 }

    @index.add_version('deadbeef', item1, get_tmp_file_path('payload1'))
    @index.add_version('deadcafe', item2, get_tmp_file_path('payload2'))

    checksum1 = Digest::SHA1.hexdigest('payload1')
    checksum2 = Digest::SHA1.hexdigest('payload2')

    expect(@index.find_by_checksum(checksum1)).to eq(item1.merge('sha1' => checksum1))
    expect(@index.find_by_checksum(checksum2)).to eq(item2.merge('sha1' => checksum2))
  end

  it 'supports name prefix' do
    item = { 'a' => 1, 'b' => 2, 'version' => 1 }

    @index = Bosh::Cli::VersionsIndex.new(@dir, 'foobar')
    @index.add_version('deadbeef', item, get_tmp_file_path('payload1'))
    expect(@index.filename(1)).to eq(File.join(@dir, 'foobar-1.tgz'))
  end

  it 'exposes the versions in the index' do
    item1 = { 'a' => 1, 'b' => 2, 'version' => '1.8-dev' }
    item2 = { 'b' => 2, 'c' => 3, 'version' => '1.9-dev' }

    @index.add_version('deadbeef', item1, get_tmp_file_path('payload1'))
    @index.add_version('deadcafe', item2, get_tmp_file_path('payload3'))

    expect(@index.versions).to eq(%w(1.8-dev 1.9-dev))
  end

  describe 'latest_version' do
    before do
      @index.add_version('fingerprint-1', { 'version' => '7' })
      @index.add_version('fingerprint-2', { 'version' => '8' })
      @index.add_version('fingerprint-3', { 'version' => '9' })
      @index.add_version('fingerprint-4', { 'version' => '8.1' })
    end

    it 'returns the maximum version' do
      expect(@index.latest_version).to eq('9')
    end
  end
end
