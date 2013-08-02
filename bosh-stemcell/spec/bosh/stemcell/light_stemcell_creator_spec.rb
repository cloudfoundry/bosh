require 'spec_helper'
require 'bosh/stemcell/light_stemcell_creator'

module Bosh::Stemcell
  describe LightStemcellCreator do
    let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell') }
    let(:light_stemcell) { instance_double('Bosh::Stemcell::Aws::LightStemcell', write_archive: nil, path: 'fake light stemcell path') }
    let(:light_stemcell_stemcell) { instance_double('Bosh::Stemcell::Stemcell') }

    before do
      Stemcell.stub(:new)
      Aws::LightStemcell.stub(:new).and_return(light_stemcell)
    end

    it 'writes a light stemcell archive with the specified stemcell' do
      Bosh::Stemcell::Aws::LightStemcell.should_receive(:new).with(stemcell).and_return(light_stemcell)
      light_stemcell.should_receive(:write_archive)
      subject.create(stemcell)
    end

    it 'creates a stemcell pointing at this archive' do
      Stemcell.should_receive(:new).with('fake light stemcell path').and_return(light_stemcell_stemcell)
      expect(subject.create(stemcell)).to be(light_stemcell_stemcell)
    end
  end
end
