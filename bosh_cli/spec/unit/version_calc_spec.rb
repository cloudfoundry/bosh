# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::VersionCalc do
  let(:calculator) { Object.new.extend(Bosh::Cli::VersionCalc) }

  describe 'major version' do
    it 'returns the integer before the first separator' do
      calculator.major_version('3').should == 3
      calculator.major_version('10').should == 10
      calculator.major_version('10.6').should == 10
      calculator.major_version('10.3-dev').should == 10
    end

  end

  describe 'minor version' do
    it 'returns the integer after the first separator' do
      calculator.minor_version('3').should == 0
      calculator.minor_version('10').should == 0
      calculator.minor_version('10.6').should == 6
      calculator.minor_version('10.3-dev').should == 3
    end
  end

  describe 'comparing' do
    describe 'only major version numbers' do
      context 'when version are strings' do
        it 'casts to and compares as integers' do
          calculator.version_cmp('10', '9').should == 1
          calculator.version_cmp('009', '10').should == -1
          calculator.version_cmp('10', '10').should == 0
        end
      end

      context 'when versions are integers' do
        it 'compares' do
          calculator.version_cmp(10, 11).should == -1
          calculator.version_cmp(43, 42).should == 1
          calculator.version_cmp(7, 7).should == 0
        end
      end
    end

    describe 'major.minor version numbers' do
      it 'compares each component as integers' do
        calculator.version_cmp('1.2', '1.3').should == -1
        calculator.version_cmp('1.2', '1.2').should == 0
        calculator.version_cmp('1.3', '1.2').should == 1
      end
    end

    describe 'major.minor.patch.and.beyond version numbers' do
      it 'compares each component as integers' do
        calculator.version_cmp('0.1.7', '0.1.7').should == 0
        calculator.version_cmp('0.1.7', '0.1.7.0').should == 0
        calculator.version_cmp('0.2.3', '0.2.3.0.8').should == -1
        calculator.version_cmp('0.1.7', '0.9.2').should == -1
        calculator.version_cmp('0.1.7.5', '0.1.7').should == 1
        calculator.version_cmp('0.1.7.4.9.9', '0.1.7.5').should == -1
      end
    end

    describe 'version numbers with -dev suffix' do
      it 'correctly orders them' do
        calculator.version_cmp('10.9-dev', '10.10-dev').should == -1
        calculator.version_cmp('10.10-dev', '10.10-dev').should == 0
        calculator.version_cmp('0.2.3-dev', '0.2.3.0.3-dev').should == -1
        calculator.version_cmp('10.10-dev', '10.9-dev').should == 1
      end

      it 'ignores -dev for comparison' do
        calculator.version_cmp('10.10', '10.10-dev').should == 0
      end
    end

    describe 'version numbers with a date (YYYY-MM-DD_hh-mm-ss) suffix' do
      it 'correctly orders them based on their version number only' do
        calculator.version_cmp('10.0.at-2013-02-27_21-38-27', '2.0.at-2013-02-26_01-26-46').should == 1
        calculator.version_cmp('2.0.at-2013-02-27_21-38-27', '10.0.at-2013-02-26_01-26-46').should == -1
        calculator.version_cmp('2.0.at-2013-02-27_21-38-27', '2.0.at-2013-02-26_01-26-46').should == 0
      end
    end

    describe 'version numbers that are dates (YYYY-MM-DD_hh-mm-ss)' do
      it 'orders them in chronological order' do
        calculator.version_cmp('2013-02-26_01-26-46', '2013-02-26_01-26-46').should == 0
        calculator.version_cmp('2013-02-26_01-26-46', '2013-02-27_21-38-27').should == -1
        calculator.version_cmp('2013-02-27_21-38-27', '2013-02-26_01-26-46').should == 1
      end
    end
  end
end
