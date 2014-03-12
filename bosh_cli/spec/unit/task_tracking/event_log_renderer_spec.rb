require 'spec_helper'

describe Bosh::Cli::TaskTracking::EventLogRenderer do
  subject(:renderer) { described_class.new }

  before { allow(Bosh::Cli::Config).to receive(:output).and_return(output) }
  let(:output) { StringIO.new }

  describe '#add_output' do
    describe 'stages' do
      it 'outputs the stage name and duration when the stage is started' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', [], 0, nil, 100))
        expect(rendered_output).to eq(<<-OUTPUT)
  Started fake-e1-stage
  Started fake-e1-stage: fake-e1-task
        OUTPUT
      end

      it 'outputs the stage name and duration when the stage is finished' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'started', [], 0, nil, 100))
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'finished', [], 0, nil, 1000))
        add_output(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'started', [], 0, nil, 100))
        add_output(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'finished', [], 0, nil, 1400))
        expect(rendered_output).to eq(<<-OUTPUT)
  Started fake-e1-stage
  Started fake-e1-stage: fake-e1-task
     Done fake-e1-stage: fake-e1-task (00:15:00)
  Started fake-e1-stage: fake-e2-task
     Done fake-e1-stage: fake-e2-task (00:21:40)
     Done fake-e1-stage (00:21:40)

        OUTPUT
      end

      it 'outputs the stage name and duration when the stage is failed' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'started', [], 0, nil, 100))
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'finished', [], 0, nil, 1000))
        add_output(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'started', [], 0, nil, 100))

        add_output(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'failed', [], 0,
          { 'error' => 'fake-error-description' }, 1400))

        expect(rendered_output).to eq(<<-OUTPUT)
  Started fake-e1-stage
  Started fake-e1-stage: fake-e1-task
     Done fake-e1-stage: fake-e1-task (00:15:00)
  Started fake-e1-stage: fake-e2-task
   Failed fake-e1-stage: fake-e2-task (00:21:40): fake-error-description
   Failed fake-e1-stage (00:21:40)
        OUTPUT
      end

      it 'outputs multiple stage names as soon as second stage is started' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', []))
        add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'started', []))
        expect(rendered_output).to eq(<<-OUTPUT)
  Started fake-e1-stage
  Started fake-e1-stage: fake-e1-task
  Started fake-e2-stage
  Started fake-e2-stage: fake-e2-task
        OUTPUT
      end

      it 'outputs multiple stage names as soon as second stage is finished' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'finished', []))
        add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'finished', []))
        expect(rendered_output).to eq(<<-OUTPUT)
     Done fake-e1-stage: fake-e1-task
     Done fake-e1-stage

     Done fake-e2-stage: fake-e2-task
     Done fake-e2-stage

        OUTPUT
      end
    end

    describe 'tasks' do
      it 'prints started marker with stage name + tags and task name when the task is started' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', []))
        expect(rendered_output).to match /^\s+Started fake-e1-stage: fake-e1-task$/

        add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'started', ['fake-e2-tag1']))
        expect(rendered_output).to match /^\s+Started fake-e2-stage fake-e2-tag1: fake-e2-task$/

        add_output(make_event('fake-e3-stage', 'fake-e3-task', 1, 1, 'started', ['fake-e3-tag1', 'fake-e3-tag2']))
        expect(rendered_output).to match /^\s+Started fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task$/
      end

      context 'task failed marker' do
        it 'prints failed marker with stage name task name' do
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', [], 0, nil, 100))
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'failed', [], 0, nil, 1000))
          expect(rendered_output).to match /^\s+Failed fake-e1-stage: fake-e1-task \(00:15:00\)$/
        end

        it 'prints failed marker with stage name,tag and task name' do
          add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'started', ['fake-e2-tag1'], 0, nil, 100))
          add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'failed', ['fake-e2-tag1'], 0, nil, 1000))
          expect(rendered_output).to match /^\s+Failed fake-e2-stage fake-e2-tag1: fake-e2-task \(00:15:00\)$/
        end

        it 'prints failed marker with stage name,tags and task name' do
          add_output(make_event('fake-e3-stage', 'fake-e3-task', 1, 1, 'started', ['fake-e3-tag1', 'fake-e3-tag2'], 0, nil, 100))
          add_output(make_event('fake-e3-stage', 'fake-e3-task', 1, 1, 'failed', ['fake-e3-tag1', 'fake-e3-tag2'], 0, nil, 1000))
          expect(rendered_output).to match /^\s+Failed fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task \(00:15:00\)$/
        end

        it 'prints failed information with included error description' do
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', [], 0, nil, 100))
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'failed', [], 0, { 'error' => 'fake-error-description' }, 1000))
          expect(rendered_output).to match /^\s+Failed fake-e1-stage: fake-e1-task \(00:15:00\): fake-error-description$/
        end

        it 'prints failed marker even when the event data is an empty hash' do
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'failed', [], 0, {}))
          rendered_output.should match /^\s+Failed fake-e1-stage: fake-e1-task$/
        end

        it 'prints failed marker even when the event data is nil' do
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'failed', [], 0, nil))
          rendered_output.should match /^\s+Failed fake-e1-stage: fake-e1-task$/
        end
      end

      context 'task finished marker' do
        it 'prints stage name and task name' do
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', [], 0, nil, 100))
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'finished', [], 0, nil, 3823))
          expect(rendered_output).to match /^\s+Done fake-e1-stage: fake-e1-task \(01:02:03\)$/
        end

        it 'print stage name, task name and tag' do
          add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'started', ['fake-e2-tag1'], 0, nil, 100))
          add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'finished', ['fake-e2-tag1'], 0, nil, 3823))
          expect(rendered_output).to match /^\s+Done fake-e2-stage fake-e2-tag1: fake-e2-task \(01:02:03\)$/
        end

        it 'print stage name, task name and tags' do
          add_output(make_event('fake-e3-stage', 'fake-e3-task', 1, 1, 'started', %W(fake-e3-tag1 fake-e3-tag2), 0, nil, 100))
          add_output(make_event('fake-e3-stage', 'fake-e3-task', 1, 1, 'finished', %W(fake-e3-tag1 fake-e3-tag2), 0, nil, 3823))
          expect(rendered_output).to match /^\s+Done fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task \(01:02:03\)$/
        end

        it 'print stage name, task name and no duration when finished time is invalid' do
          add_output(make_event('fake-e4-stage', 'fake-e4-task', 1, 1, 'started', [], 0, nil, 100))
          add_output(make_event('fake-e4-stage', 'fake-e4-task', 1, 1, 'finished', [], 0, nil, 'invalid'))
          expect(rendered_output).to match /^\s+Done fake-e4-stage: fake-e4-task$/
        end

        it 'does not print any information about progress' do
          add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'in_progress', []))
          expect(rendered_output).to eq('')
        end
      end

      it 'prints events in the correct order as they come in from the director' do
        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', [], 0, nil, 100))

        # fake-e2-stage is starting in the middle of the fake-e1-stage
        add_output(make_event('fake-e2-stage', 'fake-e2-task', 1, 1, 'started', []))

        add_output(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'finished', [], 0, nil, 1000))

        expect(rendered_output).to eq(<<-OUTPUT)
  Started fake-e1-stage
  Started fake-e1-stage: fake-e1-task
  Started fake-e2-stage
  Started fake-e2-stage: fake-e2-task
     Done fake-e1-stage: fake-e1-task (00:15:00)
     Done fake-e1-stage (00:15:00)

        OUTPUT
      end
    end

    context 'when received output contains error event' do
      before { Bosh::Cli::Config.colorize = true }
      before { allow(output).to receive(:tty?).and_return(true) }

      it 'prints error message in red with a blank line after it' do
        add_output('{"time":1394598750, "error": {"code":400007, "message":"fake-error-msg"}}')
        expect(rendered_output).to eq('Error 400007: fake-error-msg'.make_red + "\n\n")
      end

      it 'prints error without message if error message is not included' do
        add_output('{"time":1394598750, "error": {"code":400007}}')
        expect(rendered_output).to eq('Error 400007'.make_red + "\n\n")
      end

      it 'prints error message without code if error code is not included' do
        add_output('{"time":1394598750, "error": {"message":"fake-error-msg"}}')
        expect(rendered_output).to eq('Error: fake-error-msg'.make_red + "\n\n")
      end
    end

    context 'when received output contains deprecation event' do
      before { Bosh::Cli::Config.colorize = true }
      before { allow(output).to receive(:tty?).and_return(true) }

      it 'prints deprecation message in red with a blank line after it' do
        add_output('{"time":1394598750, "type": "deprecation", "message": "fake-warning-msg1"}')
        expect(rendered_output).to eq('Deprecation: fake-warning-msg1'.make_red + "\n\n")
      end
    end

    context 'when received output contains an event that is not valid JSON' do
      context 'when line starts with #' do
        it 'does not print the error since bosh director adds comments' do
          add_output('#invalid-json')
          expect(rendered_output).to be_empty
        end
      end

      context 'when line does not start with #' do
        it 'prints error about the event with a blank line after it' do
          add_output('invalid-json')
          expect(rendered_output).to match(/\AReceived invalid event: Invalid JSON.*\n\n\z/)
        end
      end
    end

    context 'when received output contains an event non-hash structure (e.g. array)' do
      it 'notifies user of about the event including its reason' do
        add_output('[]')
        expect(rendered_output).to match(/\AReceived invalid event: Hash expected, Array given.*\n\n\z/)
      end
    end

    context 'when received output contains an event that is missing keys' do
      it 'notifies user of about the event including its reason' do
        add_output('{"hash":"with-missing-keys"}')
        expect(rendered_output).to match(/\AReceived invalid event: Missing event key.*\n\n\z/)
      end
    end
  end

  describe '#started_at' do
    context 'when event state is started' do
      it 'updates total duration started at time' do
        expect {
          add_output(make_event('fake-e1-stage', 'task1', 1, 1, 'started', [], 0, nil, 101))
        }.to change { renderer.started_at }.to(Time.at(101))
      end
    end
  end

  describe '#finished_at' do
    context 'when event state is finished' do
      it 'updates total duration finished at time' do
        expect {
          add_output(make_event('fake-e1-stage', 'task1', 1, 1, 'started', [], 0, nil, 0))
          add_output(make_event('fake-e1-stage', 'task1', 1, 1, 'finished', [], 0, nil, 101))
        }.to change { renderer.finished_at }.to(Time.at(101))
      end
    end
  end

  def make_event(stage, task, index, total, state = 'started', tags = [], progress = 0, data = nil, time = nil)
    event = {
      'time' => time || Time.now.to_i,
      'stage' => stage,
      'task' => task,
      'index' => index,
      'total' => total,
      'state' => state,
      'tags' => tags,
      'progress' => progress,
    }

    event.merge!('data' => data) if data

    JSON.generate(event)
  end

  def add_output(*args)
    renderer.add_output(*args)
    renderer.refresh
  end

  def rendered_output
    renderer.refresh
    output.string
  end
end
