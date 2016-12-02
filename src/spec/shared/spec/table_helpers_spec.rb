require 'rspec'
require_relative '../support/string_helpers'
require_relative '../support/table_helpers'

module Support
  describe TableHelpers::Parser do
    let(:parser) { TableHelpers::Parser.new(source) }

    describe '#data' do
      let(:source) do
        strip_heredoc %(
          +----------+---------------+---------+------+
          | Name     | OS            | Version | CID  |
          +----------+--------------------------------+
          | stemcell | ubuntu-trusty | 3142*   | cid1 |
          | stemcell | ubuntu-trusty | 3143*   | cid2 |
          +----------+---------------+---------+------+
        )
      end

      it 'parses the table' do
        expect(parser.data).to eq([
          { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3142*', 'CID' => 'cid1' },
          { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3143*', 'CID' => 'cid2' }
        ])
      end

      context 'when the source includes additional content' do
        let(:source) do
          strip_heredoc %(
            Acting as user 'admin' on 'micro'

            +----------+---------------+---------+------+
            | Name     | OS            | Version | CID  |
            +----------+--------------------------------+
            | stemcell | ubuntu-trusty | 3142*   | cid1 |
            | stemcell | ubuntu-trusty | 3143*   | cid2 |
            +----------+---------------+---------+------+

            (*) Currently in-use

            Stemcells total: 2
          )
        end

        it 'parses the table' do
          expect(parser.data).to eq([
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3142*', 'CID' => 'cid1' },
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3143*', 'CID' => 'cid2' }
          ])
        end
      end

      context 'when there are empty elements' do
        let(:source) do
          strip_heredoc %(
            Acting as user 'admin' on 'micro'

            +----------+---------------+---------+------+
            | Name     | OS            | Version | CID  |
            +----------+--------------------------------+
            | stemcell | ubuntu-trusty |         | cid1 |
            | stemcell | ubuntu-trusty | 3143*   | cid2 |
            +----------+---------------+---------+------+

            (*) Currently in-use

            Stemcells total: 2
          )
        end

        it 'parses the table' do
          expect(parser.data).to eq([
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '', 'CID' => 'cid1' },
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3143*', 'CID' => 'cid2' }
          ])
        end
      end
    end
  end
end
