require 'bosh/template/evaluation_context'
require_relative './template_example_group'

shared_examples 'rendered *_users.erb' do
  let(:template) { File.read(File.join(File.dirname(__FILE__), erb_file_name)) }

  subject(:rendered_template_lines) do
    binding = Bosh::Template::EvaluationContext.new(properties, nil).get_binding
    ERB.new(template).result(binding).split("\n")
  end

  context 'blobstore with no agent user settings' do
    let(:properties) do
      {
        'properties' => {
          'blobstore' => {
            'director' => {
              'user' => 'director-0',
              'password' => 'oeuirgh9453yt44y98',
            },
          },
        },
      }
    end

    it 'should render *_users.erb file with director user only' do
      expect(rendered_template_lines.count).to eq(1)
      expect(rendered_template_lines).not_to include('agent-0:')
      expect(rendered_template_lines).to include('director-0:{PLAIN}oeuirgh9453yt44y98')
    end
  end

  context 'blobstore with single users settings' do
    let(:properties) do
      {
        'properties' => {
          'blobstore' => {
            'agent' => {
              'user' => 'agent-0',
              'password' => 'uyerbvfg84357gf43u',
            },
            'director' => {
              'user' => 'director-0',
              'password' => 'oeuirgh9453yt44y98',
            },
          },
        },
      }
    end

    it 'should render *_users.erb file correctly' do
      expect(rendered_template_lines.count).to eq(2)
      expect(rendered_template_lines).to include('agent-0:{PLAIN}uyerbvfg84357gf43u',
                                                 'director-0:{PLAIN}oeuirgh9453yt44y98')
    end
  end

  context 'blobstore with multiple users settings' do
    let(:properties) do
      {
        'properties' => {
          'blobstore' => {
            'agent' => {
              'user' => 'agent-0',
              'password' => 'uyerbvfg84357gf43u',
              'additional_users' => [
                {
                  'user' => 'agent-1',
                  'password' => '87y34tfgbyt4f487',
                },
                {
                  'user' => 'agent-2',
                  'password' => '78y4rfehg4f7834g',
                },
              ],
            },
            'director' => {
              'user' => 'director-0',
              'password' => 'oeuirgh9453yt44y98',
            },
          },
        },
      }
    end

    it 'should render *_users.erb file correctly' do
      expect(rendered_template_lines.count).to eq(4)
      expect(rendered_template_lines).to include('agent-0:{PLAIN}uyerbvfg84357gf43u',
                                                 'director-0:{PLAIN}oeuirgh9453yt44y98',
                                                 'agent-1:{PLAIN}87y34tfgbyt4f487',
                                                 'agent-2:{PLAIN}78y4rfehg4f7834g')
    end
  end
end

describe 'read_users.erb' do
  it_should_behave_like 'rendered *_users.erb' do
    let(:erb_file_name) { '../jobs/blobstore/templates/read_users.erb' }
  end
end

describe 'write_users.erb' do
  it_should_behave_like 'rendered *_users.erb' do
    let(:erb_file_name) { '../jobs/blobstore/templates/write_users.erb' }
  end
end
