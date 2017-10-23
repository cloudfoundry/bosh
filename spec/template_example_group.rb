shared_examples_for "a rendered file" do
  let(:content) { 'file content' }
  let(:expected_content) { "file content\n" }
  let(:file_name) do
    raise 'Override this for file name'
  end

  let(:properties) do
    raise 'Override this for binding properties'
  end

  let(:template) { File.read(File.join(File.dirname(__FILE__), file_name)) }

  subject(:rendered_template) do
    binding = Bosh::Template::EvaluationContext.new(properties, nil).get_binding
    ERB.new(template).result(binding)
  end

  it 'should render the content correctly' do
    expect(rendered_template).to eq(expected_content)
  end
end