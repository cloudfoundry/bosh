require 'spec_helper'

describe 'TemplateLink' do
  context '#parse_consumes_link' do
    context 'link definition has all required parameters' do
      let(:link_def) do
        {
          'name' => 'og_name',
          'type' => 'link_type'
        }
      end

      context 'optional parameters are not defined' do
        it 'should default "shared" to "false"' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.shared).to be_falsey
        end

        it 'should default "optional" to "false"' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.optional).to be_falsey
        end
      end

      context '"shared" parameter is defined' do
        it 'should be ignored and return false' do
          link_def['shared'] = true
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.shared).to be_falsey
        end
      end

      context '"optional" param is defined' do
        it 'should return "true"' do
          link_def['optional'] = true
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.optional).to be_truthy
        end
      end

      context '"from" is defined' do
        it 'should set name as the alias name' do
          link_def['from'] = 'alias_name'
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.name).to eq('alias_name')
        end

        it 'should set original_name as the original name' do
          link_def['from'] = 'alias_name'
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.original_name).to eq('og_name')
        end

        context 'value is separated by "."' do
          it 'should use the last segment of alias as name' do
            link_def['from'] = 'a.b.c'
            link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
            expect(link.name).to eq('c')
          end
        end
      end

      context '"from" is not defined' do
        it 'should set name as the orignal name' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link(link_def)
          expect(link.name).to eq('og_name')
        end
      end
    end

    context 'link definition is not a hash' do
      it 'should raise an error' do
        expect{
          Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link('not a hash')
        }.to raise_error(Bosh::Director::JobInvalidLinkSpec, "Link 'not a hash' must be a hash with name and type")
      end
    end

    context 'link definition is missing "type" key' do
      it 'should raise an error' do
        expect{
          Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link({})
        }.to raise_error(Bosh::Director::JobInvalidLinkSpec, "Link '{}' must be a hash with name and type")
      end
    end

    context 'link definition is not a hash' do
      it 'should raise an error' do
        expect{
          Bosh::Director::DeploymentPlan::TemplateLink.parse_consumes_link({'type' => ''})
        }.to raise_error(Bosh::Director::JobInvalidLinkSpec, %Q{Link '{"type"=>""}' must be a hash with name and type})
      end
    end
  end

  context '#parse_provides_link' do
    context 'link definition has required parameters' do
      let(:link_def) do
        {
          'name' => 'og_name',
          'type' => 'link_type'
        }
      end

      context 'and optional is defined' do
        it 'should raise an error' do
          link_def['optional'] = true
          expect{
            Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link(link_def)
          }.to raise_error(Bosh::Director::JobInvalidLinkSpec, %Q{Link '#{link_def['name']}' of type 'link_type' is a provides link, not allowed to have 'optional' key})
        end
      end

      context 'and alias is specified (as)' do
        before do
          link_def['as'] = 'alias_name'
        end

        it 'should set name to be the alias' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link(link_def)
          expect(link.name).to eq('alias_name')
        end

        it 'should set original_name as the original name' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link(link_def)
          expect(link.original_name).to eq('og_name')
        end
      end

      context 'and no alias is specified (as)' do
        it 'should set name as the original name' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link(link_def)
          expect(link.name).to eq('og_name')
        end

        it 'should set original_name as the original name' do
          link = Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link(link_def)
          expect(link.original_name).to eq('og_name')
        end
      end
    end

    context 'link definition is not a hash' do
      it 'should raise an error' do
        expect{
          Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link('not a hash')
        }.to raise_error(Bosh::Director::JobInvalidLinkSpec, "Link 'not a hash' must be a hash with name and type")
      end
    end
    
    context 'link definition is missing "type" key' do
      it 'should raise an error' do
        expect{
          Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link({})
        }.to raise_error(Bosh::Director::JobInvalidLinkSpec, "Link '{}' must be a hash with name and type")
      end
    end

    context 'link definition is not a hash' do
      it 'should raise an error' do
        expect{
          Bosh::Director::DeploymentPlan::TemplateLink.parse_provides_link({'type' => ''})
        }.to raise_error(Bosh::Director::JobInvalidLinkSpec, %Q{Link '{"type"=>""}' must be a hash with name and type})
      end
    end
  end
end