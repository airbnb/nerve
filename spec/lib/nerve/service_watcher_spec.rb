require 'spec_helper'
require 'timeout'

describe Nerve::ServiceWatcher do
  describe 'initialize' do
    let(:service) { build(:service) }

    it 'can successfully initialize' do
      Nerve::ServiceWatcher.new(service)
    end

    it 'requires minimum parameters' do
      %w[name instance_id host port].each do |req|
        service_without = service.dup
        service_without.delete(req)

        expect { Nerve::ServiceWatcher.new(service_without) }.to raise_error
      end
    end
  end

  describe 'check_and_report' do
    let(:service_watcher) { Nerve::ServiceWatcher.new(build(:service)) }
    let(:reporter) { service_watcher.instance_variable_get(:@reporter) }

    it 'pings the reporter' do
      expect(reporter).to receive(:ping?)
      service_watcher.check_and_report
    end

    it 'reports the service as down when the checks fail' do
      expect(service_watcher).to receive(:check?).and_return(false)
      expect(reporter).to receive(:report_down).and_return(true)
      expect(service_watcher.check_and_report).to be true
    end

    it 'reports the service as up when the checks succeed' do
      expect(service_watcher).to receive(:check?).and_return(true)
      expect(reporter).to receive(:report_up).and_return(true)
      expect(service_watcher.check_and_report).to be true
    end

    it 'doesn\'t report if the status hasn\'t changed' do
      expect(service_watcher).to receive(:check?).and_return(true)
      service_watcher.instance_variable_set(:@was_up, true)

      expect(reporter).to receive(:ping?).and_return(true)
      expect(reporter).not_to receive(:report_up)
      expect(reporter).not_to receive(:report_down)
      expect(service_watcher.check_and_report).to be true
    end

    context "when reporter failed to report up/down" do
      it 'returns false when report down' do
        expect(service_watcher).to receive(:check?).and_return(false)
        expect(reporter).to receive(:report_down).and_return(false)
        expect(service_watcher.check_and_report).to be false
      end

      it 'returns false when report up' do
        expect(service_watcher).to receive(:check?).and_return(true)
        expect(reporter).to receive(:report_up).and_return(false)
        expect(service_watcher.check_and_report).to be false
      end
    end
  end

  describe 'run' do
    let(:check_interval) { 0 }
    let(:service_watcher) { Nerve::ServiceWatcher.new(build(:service, :check_interval => check_interval)) }
    let(:reporter) { service_watcher.instance_variable_get(:@reporter) }
    before { $EXIT = false }

    it 'starts the reporter' do
      $EXIT = true
      expect(reporter).to receive(:start)
      service_watcher.run()
    end

    it 'calls check and report repeatedly' do
      count = 0

      # expect it to be called twice
      expect(service_watcher).to receive(:check_and_report).twice do
        # on the second call, set exit to true
        $EXIT = true if count == 1
        count += 1
      end

      service_watcher.run()
    end

    context 'when the check interval is long' do
      let(:check_interval) { 10 }

      it 'still exits quickly during nap time' do
        expect(service_watcher).to receive(:check_and_report) do
          $EXIT = true
        end

        expect{ Timeout::timeout(1) { service_watcher.run() } }.not_to raise_error
      end
    end

    context 'when check and report has repeated failures' do
      it 'quits the loop after eaching the max number of repeated failures' do
        # default max repeated failure is 10
        expect(service_watcher).to receive(:check_and_report).exactly(10).times.and_return(false)
        service_watcher.run()
        expect(service_watcher.alive?).to be false
      end

      it 'continues the loop if not reaching max number of repeated failures' do
        # default max repeated failure is 10
        count = 0

        expect(service_watcher).to receive(:check_and_report).exactly(101).times do
          $EXIT = true if count == 100
          count += 1
          # so that check_and_report returns 9 false followed by 1 true and repeats the sequence
          count % 10 == 9
        end

        service_watcher.run()
        expect(service_watcher.alive?).to be false
      end
    end
  end
end
