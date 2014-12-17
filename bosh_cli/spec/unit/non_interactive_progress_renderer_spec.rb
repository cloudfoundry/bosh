require 'spec_helper'

describe 'NonInteractiveProgressRenderer' do

  let(:renderer){ Bosh::Cli::NonInteractiveProgressRenderer.new }
  let(:label) { "foo" }
  let(:error) { "an error" }

  context 'when there is a single active task' do
    let(:path) { "/task/0" }

    it 'renders initial progress' do
      expect_render(path, label, renderer)
      renderer.start(path, label)
    end

    it 'does not render subsequent progress' do
      renderer.start(path, label)

      expect(renderer).to_not receive(:say)
      renderer.progress(path, label, 50)
    end

    it 'renders error' do
      renderer.start(path, label)
      renderer.progress(path, label, 50)
      expect_render(path, error, renderer)
      renderer.error(path, error)
    end

    it 'renders finished' do
      renderer.start(path, label)
      renderer.progress(path, label, 50)
      expect_render(path, label, renderer)
      renderer.finish(path, label)
    end
  end

  context 'when there are multiple active downloads' do
    let(:path1) { "/task/0" }
    let(:path2) { "/task/1" }
    let(:path3) { "/task/2" }

    it 'renders initial progress' do
      expect_render(path1, label, renderer)
      renderer.start(path1, label)

      expect_render(path2, label, renderer)
      renderer.start(path2, label)

      expect_render(path3, label, renderer)
      renderer.start(path3, label)
    end

    it 'does not render subsequent progress' do
      renderer.start(path1, label)
      renderer.start(path2, label)
      renderer.start(path3, label)

      expect(renderer).to_not receive(:say)

      renderer.progress(path1, label, 50)
      renderer.progress(path2, label, 51)
      renderer.progress(path3, label, 52)
    end

    it 'renders error' do
      renderer.start(path1, label)
      renderer.start(path2, label)
      renderer.start(path3, label)

      renderer.progress(path1, label, 50)
      renderer.progress(path2, label, 51)
      renderer.progress(path3, label, 52)

      expect_render(path1, error, renderer)
      renderer.error(path1, error)
      expect_render(path2, error, renderer)
      renderer.error(path2, error)
      expect_render(path3, error, renderer)
      renderer.error(path3, error)
    end

    it 'renders finished' do
      renderer.start(path1, label)
      renderer.start(path2, label)
      renderer.start(path3, label)

      renderer.progress(path1, label, 50)
      renderer.progress(path2, label, 51)
      renderer.progress(path3, label, 52)

      expect_render(path1, label, renderer)
      renderer.finish(path1, label)
      expect_render(path2, label, renderer)
      renderer.finish(path2, label)
      expect_render(path3, label, renderer)
      renderer.finish(path3, label)
    end
  end
end

def expect_render(path, label, renderer)
  allow(renderer).to receive(:say).exactly(1).times
  expect(path).to receive(:truncate).and_return(path)
  expect(renderer).to receive(:say).with("#{path} #{label}")
end
