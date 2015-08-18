require 'spec_helper'

describe Bosh::Cli::TaskTracking::EventLogRenderer do
  subject(:renderer) { described_class.new }

  before { allow(Bosh::Cli::Config).to receive(:output).and_return(output) }
  let(:output) { StringIO.new }

  describe '#add_output' do
    it 'outputs multiple events with interleaved starts, ends, failures' do
      add_output(make_event('fake-s1-stage', 'fake-t1-task', 1, 1, 'started', ['fake-e1-tag1'], 0, nil, 100))
      add_output(make_event('fake-s1-stage', 'fake-t1-task', 1, 1, 'finished', ['fake-e1-tag1'], 0, nil, 1000))

      add_output(make_event('fake-s2-stage', 'fake-t1-task', 1, 4, 'started', [], 0, nil, 100))
      add_output(make_event('fake-s2-stage', 'fake-t2-task', 2, 4, 'started', [], 0, nil, 100))
      add_output(make_event('fake-s2-stage', 'fake-t2-task', 2, 4, 'finished', [], 0, nil, 130))
      add_output(make_event('fake-s2-stage', 'fake-t3-task', 3, 4, 'started', [], 0, nil, 160))
      add_output(make_event('fake-s2-stage', 'fake-t2-task', 4, 4, 'started', [], 0, nil, 190))
      add_output(make_event('fake-s2-stage', 'fake-t2-task', 4, 4, 'finished', [], 0, nil, 220))
      add_output(make_event('fake-s2-stage', 'fake-t1-task', 1, 4, 'finished', [], 0, nil, 1000))
      add_output(make_event('fake-s2-stage', 'fake-t3-task', 3, 4, 'failed', [], 0,
        {'error' => 'fake-error-description'}, 1400))

      add_output(make_event('fake-s3-stage', 'fake-t1-task', 1, 2, 'started', [], 0, nil, 100))
      add_output(make_event('fake-s4-stage', 'fake-t1-task', 1, 2, 'started', [], 0, nil, 100))
      add_output(make_event('fake-s4-stage', 'fake-t2-task', 2, 2, 'started', [], 0, nil, 100))
      add_output(make_event('fake-s4-stage', 'fake-t1-task', 1, 2, 'failed', [], 0, {}, 100))
      add_output(make_event('fake-s3-stage', 'fake-t2-task', 2, 2, 'started', [], 0, nil, 100))
      add_output(make_event('fake-s3-stage', 'fake-t2-task', 2, 2, 'finished', [], 0, nil, 100))
      add_output(make_event('fake-s3-stage', 'fake-t1-task', 1, 2, 'finished', [], 0, nil, 100))
      add_output(make_event('fake-s4-stage', 'fake-t2-task', 2, 2, 'finished', [], 0, nil, 100))

      expect(rendered_output).to eq(<<-OUTPUT)
  Started fake-s1-stage fake-e1-tag1 > fake-t1-task. Done (00:15:00)

  Started fake-s2-stage
  Started fake-s2-stage > fake-t1-task
  Started fake-s2-stage > fake-t2-task. Done (00:00:30)
  Started fake-s2-stage > fake-t3-task
  Started fake-s2-stage > fake-t2-task. Done (00:00:30)
     Done fake-s2-stage > fake-t1-task (00:15:00)
   Failed fake-s2-stage > fake-t3-task: fake-error-description (00:20:40)
   Failed fake-s2-stage (00:21:40)

  Started fake-s3-stage
  Started fake-s3-stage > fake-t1-task

  Started fake-s4-stage
  Started fake-s4-stage > fake-t1-task
  Started fake-s4-stage > fake-t2-task
   Failed fake-s4-stage > fake-t1-task (00:00:00)

  Started fake-s3-stage > fake-t2-task. Done (00:00:00)
     Done fake-s3-stage > fake-t1-task (00:00:00)
     Done fake-s3-stage (00:00:00)

     Done fake-s4-stage > fake-t2-task (00:00:00)
   Failed fake-s4-stage (00:00:00)
      OUTPUT
    end

    context 'when received output contains error event' do
      before { Bosh::Cli::Config.colorize = true }
      before { allow(output).to receive(:tty?).and_return(true) }

      it 'prints error message in red with a blank line after it' do
        add_output('{"time":1394598750, "error": {"code":400007, "message":"fake-error-msg"}}')
        expect(rendered_output).to eq('Error 400007: fake-error-msg'.make_red + "\n")
      end

      it 'prints error without message if error message is not included' do
        add_output('{"time":1394598750, "error": {"code":400007}}')
        expect(rendered_output).to eq('Error 400007'.make_red + "\n")
      end

      it 'prints error message without code if error code is not included' do
        add_output('{"time":1394598750, "error": {"message":"fake-error-msg"}}')
        expect(rendered_output).to eq('Error: fake-error-msg'.make_red + "\n")
      end
    end

    context 'when received output contains deprecation event' do
      before { Bosh::Cli::Config.colorize = true }
      before { allow(output).to receive(:tty?).and_return(true) }

      it 'prints deprecation message in red with a blank line after it' do
        add_output('{"time":1394598750, "type": "deprecation", "message": "fake-warning-msg1"}')
        expect(rendered_output).to eq('Deprecation: fake-warning-msg1'.make_red + "\n")
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
          expect(rendered_output).to match(/\AReceived invalid event: Invalid JSON.*\n\z/)
        end
      end
    end

    context 'when received output contains an event non-hash structure (e.g. array)' do
      it 'notifies user of the event including its reason' do
        add_output('[]')
        expect(rendered_output).to match(/\AReceived invalid event: Hash expected, Array given.*\n\z/)
      end
    end

    context 'when received output contains an event that is missing keys' do
      it 'notifies user of about the event including its reason' do
        add_output('{"hash":"with-missing-keys"}')
        expect(rendered_output).to match(/\AReceived invalid event: Missing event key.*\n\z/)
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

      it 'records first non-zero duration event as started_at time' do
        add_output(make_event('fake-e1-stage', 'task1', 1, 1, 'started', [], 0, nil, 0))
        add_output(make_event('fake-e1-stage', 'task2', 1, 1, 'started', [], 0, nil, 102))

        expect(renderer.started_at).to eq(Time.at(102))
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

      it 'records last non-zero duration event as finished_at time' do
        add_output(make_event('fake-e1-stage', 'task2', 1, 1, 'started', [], 0, nil, 102))
        add_output(make_event('fake-e1-stage', 'task1', 1, 1, 'started', [], 0, nil, 0))

        expect(renderer.finished_at).to eq(Time.at(102))
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
    renderer.finish(:fake_state)
    output.string
  end
end
