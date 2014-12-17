require 'spec_helper'

describe 'InteractiveProgressRenderer' do

  let(:renderer){ Bosh::Cli::InteractiveProgressRenderer.new }
  let(:label) { "foo" }
  let(:error) { "an error" }

  context 'when there is a single active task' do
    let(:path) { "/task/0" }

    it 'renders initial progress' do
      expect_start_render(path, label, renderer)
      renderer.start(path, label)
    end

    it 'renders subsequent progress' do
      renderer.start(path, label)

      expect_progress_render(path, "#{label} (50%)", 1, renderer)
      renderer.progress(path, label, 50)
    end

    it 'renders error' do
      renderer.start(path, label)
      renderer.progress(path, label, 50)
      expect_error_render(path, error, 1, renderer)
      renderer.error(path, error)
    end

    it 'renders finished' do
      renderer.start(path, label)
      renderer.progress(path, label, 50)
      expect_finish_render(path, label, 1, renderer)
      renderer.finish(path, label)
    end
  end

  context 'when there are multiple active downloads' do
    let(:path1) { "/task/0" }
    let(:path2) { "/task/1" }
    let(:path3) { "/task/2" }

    it 'renders initial progress' do
      expect_start_render(path1, label, renderer)
      renderer.start(path1, label)

      expect_start_render(path2, label, renderer)
      renderer.start(path2, label)

      expect_start_render(path3, label, renderer)
      renderer.start(path3, label)
    end

    it 'renders subsequent progress' do
      renderer.start(path1, label)
      renderer.start(path2, label)
      renderer.start(path3, label)

      expect_progress_render(path1, "#{label} (50%)", 3, renderer)
      renderer.progress(path1, label, 50)

      expect_progress_render(path2, "#{label} (51%)", 2, renderer)
      renderer.progress(path2, label, 51)

      expect_progress_render(path3, "#{label} (52%)", 1, renderer)
      renderer.progress(path3, label, 52)
    end

    it 'renders error' do
      renderer.start(path1, label)
      renderer.start(path2, label)
      renderer.start(path3, label)

      renderer.progress(path1, label, 50)
      renderer.progress(path2, label, 51)
      renderer.progress(path3, label, 52)

      expect_error_render(path1, error, 3, renderer)
      renderer.error(path1, error)
      expect_error_render(path2, error, 2, renderer)
      renderer.error(path2, error)
      expect_error_render(path3, error, 1, renderer)
      renderer.error(path3, error)
    end

    it 'renders finished' do
      renderer.start(path1, label)
      renderer.start(path2, label)
      renderer.start(path3, label)

      renderer.progress(path1, label, 50)
      renderer.progress(path2, label, 51)
      renderer.progress(path3, label, 52)

      expect_finish_render(path1, label, 3, renderer)
      renderer.finish(path1, label)
      expect_finish_render(path2, label, 2, renderer)
      renderer.finish(path2, label)
      expect_finish_render(path3, label, 1, renderer)
      renderer.finish(path3, label)
    end
  end
end

def expect_start_render(path, label, renderer)
  allow(renderer).to receive(:say).exactly(7).times
  expect(path).to receive(:truncate).and_return(path)
  expect(path).to receive(:make_yellow).and_return(path)
  expect(renderer).to receive(:say).with(path, " \n")
  expect(renderer).to receive(:say).with("\e[s", "")
  expect(renderer).to receive(:say).with("\e[1A", "")
  expect(renderer).to receive(:say).with("\e[#{path.length+1}C", "")
  expect(renderer).to receive(:say).with("\e[K", "")
  expect(renderer).to receive(:say).with(label, "")
  expect(renderer).to receive(:say).with("\e[u", "")
end

def expect_progress_render(path, label, index, renderer)
  allow(renderer).to receive(:say).exactly(6).times
  expect(path).to receive(:truncate).and_return(path)
  expect(path).to_not receive(:make_yellow)
  expect(renderer).to receive(:say).with("\e[s", "")
  expect(renderer).to receive(:say).with("\e[#{index}A", "")
  expect(renderer).to receive(:say).with("\e[#{path.length+1}C", "")
  expect(renderer).to receive(:say).with("\e[K", "")
  expect(renderer).to receive(:say).with(label, "")
  expect(renderer).to receive(:say).with("\e[u", "")
end

def expect_finish_render(path, label, index, renderer)
  allow(renderer).to receive(:say).exactly(6).times
  expect(path).to receive(:truncate).and_return(path)
  expect(path).to_not receive(:make_yellow)
  expect(label).to receive(:make_green).and_return(label)
  expect(renderer).to receive(:say).with("\e[s", "")
  expect(renderer).to receive(:say).with("\e[#{index}A", "")
  expect(renderer).to receive(:say).with("\e[#{path.length+1}C", "")
  expect(renderer).to receive(:say).with("\e[K", "")
  expect(renderer).to receive(:say).with(label, "")
  expect(renderer).to receive(:say).with("\e[u", "")
end

def expect_error_render(path, message, index, renderer)
  allow(renderer).to receive(:say).exactly(6).times
  expect(path).to receive(:truncate).and_return(path)
  expect(path).to_not receive(:make_yellow)
  expect(message).to receive(:make_red).and_return(message)
  expect(renderer).to receive(:say).with("\e[s", "")
  expect(renderer).to receive(:say).with("\e[#{index}A", "")
  expect(renderer).to receive(:say).with("\e[#{path.length+1}C", "")
  expect(renderer).to receive(:say).with("\e[K", "")
  expect(renderer).to receive(:say).with(message, "")
  expect(renderer).to receive(:say).with("\e[u", "")
end
