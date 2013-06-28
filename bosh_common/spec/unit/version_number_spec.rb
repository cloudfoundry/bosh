require 'common/version_number'

describe Bosh::Common::VersionNumber do
  def version(value)
    Bosh::Common::VersionNumber.new(value)
  end

  describe 'major version' do
    it 'returns the integer before the first separator' do
      expect(version('3').major).to eq 3
      expect(version('10').major).to eq 10
      expect(version('10.6').major).to eq 10
      expect(version('10.3-dev').major).to eq 10
    end
  end

  describe 'minor version' do
    it 'returns the integer after the first separator' do
      expect(version('3').minor).to eq 0
      expect(version('10').minor).to eq 0
      expect(version('10.6').minor).to eq 6
      expect(version('10.3-dev').minor).to eq 3
    end
  end

  describe 'comparing' do
    describe 'only major version numbers' do
      context 'when version are strings' do
        it 'casts to and compares as integers' do
          expect(version('10')).to be > version('9')
          expect(version('009')).to be < version('10')
          expect(version('10')).to eq version('10')
        end
      end

      context 'when versions are integers' do
        it 'compares' do
          expect(version(10)).to be < version(11)
          expect(version(43)).to be > version(42)
          expect(version(7)).to eq version(7)
        end
      end
    end

    describe 'major.minor version numbers' do
      it 'compares each component as integers' do
        expect(version('1.2')).to be < version('1.3')
        expect(version('1.2')).to eq version('1.2')
        expect(version('1.3')).to be > version('1.2')
      end
    end

    describe 'major.minor.patch.and.beyond version numbers' do
      it 'compares each component as integers' do
        expect(version('0.1.7')).to eq version('0.1.7')
        expect(version('0.1.7')).to eq version('0.1.7.0')
        expect(version('0.2.3')).to be < version('0.2.3.0.8')
        expect(version('0.1.7')).to be < version('0.9.2')
        expect(version('0.1.7.5')).to be > version('0.1.7')
        expect(version('0.1.7.4.9.9')).to be < version('0.1.7.5')
      end
    end

    describe 'version numbers with -dev suffix' do
      it 'correctly orders them' do
        expect(version('10.9-dev')).to be < version('10.10-dev')
        expect(version('10.10-dev')).to eq version('10.10-dev')
        expect(version('0.2.3-dev')).to be < version('0.2.3.0.3-dev')
        expect(version('10.10-dev')).to be > version('10.9-dev')
      end

      it 'ignores -dev for comparison' do
        expect(version('10.10')).to eq version('10.10-dev')
      end
    end

    describe 'version numbers with a date (YYYY-MM-DD_hh-mm-ss) suffix' do
      it 'correctly orders them based on their version number only' do
        expect(version('10.0.at-2013-02-27_21-38-27')).to be > version('2.0.at-2013-02-26_01-26-46')
        expect(version('2.0.at-2013-02-27_21-38-27')).to be < version('10.0.at-2013-02-26_01-26-46')
        expect(version('2.0.at-2013-02-27_21-38-27')).to eq version('2.0.at-2013-02-26_01-26-46')
      end
    end

    describe 'version numbers that are dates (YYYY-MM-DD_hh-mm-ss)' do
      it 'orders them in chronological order' do
        expect(version('2013-02-26_01-26-46')).to eq version('2013-02-26_01-26-46')
        expect(version('2013-02-26_01-26-46')).to be < version('2013-02-27_21-38-27')
        expect(version('2013-02-27_21-38-27')).to be > version('2013-02-26_01-26-46')
      end
    end
  end

  describe 'final?' do
    it 'marks a release as final if does not end in -dev' do
      expect(version('10.1-dev')).to_not be_final
      expect(version('10.1')).to be_final
    end
  end

  describe 'next_minor' do
    it 'returns a new VersionNumber with the next sequential minor version' do
      expect(version('10').next_minor).to eq version('10.1')
      expect(version('10.1').next_minor).to eq version('10.2')
      expect(version('10.1.2').next_minor).to eq version('10.2.0')
    end

    it 'does not modify the existing version' do
      version = version('10')

      expect {
        version.next_minor
      }.to_not change(version, :to_s)
    end
  end

  describe 'dev' do
    it 'returns a new VersionNumber with -dev suffix' do
      expect(version('10').dev).to_not be_final
    end

    it 'does not add more than one -dev suffix' do
      expect(version('10-dev').dev.to_s).to eq '10-dev'
    end

    it 'does not modify the existing version' do
      version = version('10')

      expect {
        version.dev
      }.to_not change(version, :to_s)
    end
  end
end