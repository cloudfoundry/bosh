require 'spec_helper'
require 'bosh/director/core/templates/rendered_job_template'

module Bosh::Director::Core::Templates
  describe RenderedJobTemplate do
    describe '#template_hash' do
      let(:unordered_templates) do
        [
          instance_double(
            'Bosh::Director::Core::Templates::RenderedFileTemplate',
            src_name: 'foo.erb',
            contents: 'rendered foo erb',
          ),
          instance_double(
            'Bosh::Director::Core::Templates::RenderedFileTemplate',
            src_name: 'bar.erb',
            contents: 'rendered bar erb',
          ),
        ]
      end
      subject(:template) { described_class.new('template name', 'monit file', unordered_templates) }

      it 'caculates the sha1 of the rendered erb content and returns hexdigest' do
        fake_digester = double('digester')
        Digest::SHA1.stub(new: fake_digester)
        expect(fake_digester).to receive(:<<).with('monit file').ordered
        expect(fake_digester).to receive(:<<).with('rendered bar erb').ordered
        expect(fake_digester).to receive(:<<).with('rendered foo erb').ordered
        expect(fake_digester).to receive(:hexdigest).with(no_args).ordered.and_return('the hexdigest')

        expect(template.template_hash).to eq('the hexdigest')
      end
    end
  end
end
