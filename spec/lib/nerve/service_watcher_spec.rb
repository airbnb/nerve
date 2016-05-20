require 'spec_helper'
require 'timeout'

describe Nerve::ServiceWatcher do
  describe 'initialize' do
    let(:service) { build(:service) }

    it 'can successfully initialize' do
      Nerve::ServiceWatcher.new(service)
    end

    it 'requires minimum parameters' do
      %w[name instance_id host].each do |req|
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
      expect(reporter).to receive(:report_down)
      service_watcher.check_and_report
    end

    it 'reports the service as up when the checks succeed' do
      expect(service_watcher).to receive(:check?).and_return(true)
      expect(reporter).to receive(:report_up)
      service_watcher.check_and_report
    end

    it 'doesn\'t report if the status hasn\'t changed' do
      expect(service_watcher).to receive(:check?).and_return(true)

      expect(reporter).to receive(:report_up).once
      expect(reporter).not_to receive(:report_down)
      service_watcher.check_and_report
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
  end
end
