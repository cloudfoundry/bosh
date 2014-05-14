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
    @index.version_exists?(1).should be(false)
    @index['deadbeef'].should be_nil
    @index.latest_version.should be_nil
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
    expect(@index.latest_version).to be_nil
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

    expect(@index.latest_version).to eq(2)
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

  it 'it uses the last version in the index as the latest version' do
    item1 = { 'a' => 1, 'b' => 2, 'version' => 'z' }
    item2 = { 'a' => 3, 'b' => 4, 'version' => 'y' }
    item3 = { 'a' => 3, 'b' => 4, 'version' => 'a' }

    @index.add_version('deadbeef', item1, get_tmp_file_path('payload1'))
    @index.add_version('deadcafe', item2, get_tmp_file_path('payload2'))
    expect(@index.latest_version).to eq('y')
    @index.add_version('addedface', item3, get_tmp_file_path('payload2'))
    expect(@index.latest_version).to eq('a')
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
end
