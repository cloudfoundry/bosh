require 'rspec'
require_relative '../support/table_helpers'

module Support
  describe TableHelpers::Parser do
    let(:parser) { TableHelpers::Parser.new(source) }

    describe '#data' do
      let(:source) do
        %({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": [
                "Name",
                "Version",
                "OS",
                "CID"
            ],
            "Rows": [
                [
                    "stemcell",
                    "3142*",
                    "ubuntu-trusty",
                    "cid1"
                ],
                [
                    "stemcell",
                    "3143*",
                    "ubuntu-trusty",
                    "cid2"
                ]
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
      end

      it 'parses the table' do
        expect(parser.data).to eq([
          { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3142*', 'CID' => 'cid1' },
          { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3143*', 'CID' => 'cid2' }
        ])
      end

      context 'when the output is non-json' do
        let(:source) do
          'I     Am    A     Table'
        end

        it 'raises an error' do
          expect { parser.data }.to raise_error('Be sure to pass `json: true` arg to bosh_runner.run')
        end
      end

      context 'when there are empty elements' do
        let(:source) do
          %({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": [
                "Name",
                "Version",
                "OS",
                "CID"
            ],
            "Rows": [
                [
                    "stemcell",
                    "",
                    "ubuntu-trusty",
                    "cid1"
                ],
                [
                    "stemcell",
                    "3143*",
                    "ubuntu-trusty",
                    "cid2"
                ]
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses the table' do
          expect(parser.data).to eq([
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '', 'CID' => 'cid1' },
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '3143*', 'CID' => 'cid2' }
          ])
        end
      end

      context 'multiple tables' do
        let(:source) do
          %({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": [
                "Name",
                "Version",
                "OS",
                "CID"
            ],
            "Rows": [
                [
                    "stemcell",
                    "",
                    "ubuntu-trusty",
                    "cid1"
                ]
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        },
        {
            "Content": "releases",
            "Header": [
                "Name",
                "Version"
            ],
            "Rows": [
                [
                    "release",
                    "1.2.3"
                ]
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses the table' do
          expect(parser.data).to eq([
            { 'Name' => 'stemcell', 'OS' => 'ubuntu-trusty', 'Version' => '', 'CID' => 'cid1' },
            { 'Name' => 'release', 'Version' => '1.2.3' }
          ])
        end
      end

      context 'table has no rows' do
        let(:source) do
          %({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": [
                "Name",
                "Version",
                "OS",
                "CID"
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses the table and returns empty list' do
          expect(parser.data).to eq([])
        end
      end

      context 'table has no header' do
        let(:source) do
          %({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": null,
            "Rows": [
                [
                    "stemcell",
                    "",
                    "ubuntu-trusty",
                    "cid1"
                ],
                [
                    "stemcell",
                    "",
                    "ubuntu-trusty",
                    "cid1"
                ]
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses the table and returns empty list' do
          expect(parser.data).to eq([])
        end
      end
    end
  end
end
