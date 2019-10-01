require 'spec_helper'
require 'timeout'
require 'active_support/all'
require 'active_support/testing/time_helpers'

describe Nerve::ServiceWatcher do
  include ActiveSupport::Testing::TimeHelpers

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
    let(:service_watcher) { Nerve::ServiceWatcher.new(build(:service, :check_mocked => check_mocked, :rate_limiting => rate_limit_config)) }
    let(:reporter) { service_watcher.instance_variable_get(:@reporter) }
    let(:check_mocked) { false }
    let(:rate_limit_config) { {'shadow_mode' => false} }

    context 'when pinging of reporter succeeds' do
      it 'pings the reporter' do
        expect(reporter).to receive(:ping?).and_return(true)
        service_watcher.check_and_report
      end

      it 'reports the service as down when the checks fail' do
        expect(reporter).to receive(:ping?).and_return(true)
        expect(service_watcher).to receive(:check?).and_return(false)
        expect(reporter).to receive(:report_down).and_return(true)
        expect(service_watcher.check_and_report).to be true
      end

      it 'reports the service as up when the checks succeed' do
        expect(reporter).to receive(:ping?).and_return(true)
        expect(service_watcher).to receive(:check?).and_return(true)
        expect(reporter).to receive(:report_up).and_return(true)
        expect(service_watcher.check_and_report).to be true
      end

      context "when reporter failed to report up/down" do
        it 'returns false when report down' do
          expect(reporter).to receive(:ping?).and_return(true)
          expect(service_watcher).to receive(:check?).and_return(false)
          expect(reporter).to receive(:report_down).and_return(false)
          expect(service_watcher.check_and_report).to be false
        end

        it 'returns false when report up' do
          expect(reporter).to receive(:ping?).and_return(true)
          expect(service_watcher).to receive(:check?).and_return(true)
          expect(reporter).to receive(:report_up).and_return(false)
          expect(service_watcher.check_and_report).to be false
        end
      end

      context 'when throttled' do
        before {
          # Freeze time
          travel_to Time.now

          allow(reporter).to receive(:ping?).and_return(true)
          allow(service_watcher).to receive(:check?).and_return(true)

          # 100 is maximum burst
          for _ in 0..100
            service_watcher.check_and_report
            service_watcher.instance_variable_set(:@was_up, false)
          end
        }

        it 'still pings reporter' do
          expect(reporter).to receive(:ping?)
          service_watcher.check_and_report
        end

        it 'still checks service health' do
          expect(reporter).to receive(:ping?).and_return(true)
          expect(service_watcher).to receive(:check?)
          service_watcher.check_and_report
        end

        it 'doesn\'t try to report' do
          expect(reporter).to receive(:ping?).and_return(true)
          expect(service_watcher).to receive(:check?).and_return(true)

          expect(reporter).not_to receive(:report_up)
          expect(reporter).not_to receive(:report_down)
          expect(service_watcher.check_and_report).to be nil
        end

        it 'reports new status when no longer throttled' do
          # Increasing time will remove the throttle
          travel 1.minute

          expect(reporter).to receive(:ping?).and_return(true)
          expect(service_watcher).to receive(:check?).and_return(true)
          expect(reporter).to receive(:report_up).and_return(true)
          expect(service_watcher.check_and_report).to be true
        end
      end

      it 'doesn\'t report if the status hasn\'t changed' do
        expect(reporter).to receive(:ping?).and_return(true)
        expect(service_watcher).to receive(:check?).and_return(true)
        service_watcher.instance_variable_set(:@was_up, true)

        expect(reporter).not_to receive(:report_up)
        expect(reporter).not_to receive(:report_down)
        expect(service_watcher.check_and_report).to be true
      end

      context 'when the service is flappy' do
        before {
          # freeze time
          travel_to Time.now

          allow(reporter).to receive(:ping?).and_return(true)
          allow(service_watcher).to receive(:check?) { rand() >= 0.5 }

          for _ in 0..100
            service_watcher.check_and_report
          end
        }

        it 'throttles reporting' do
          expect(reporter).not_to receive(:report_up)
          expect(reporter).not_to receive(:report_down)
          expect(service_watcher.check_and_report).to be nil
        end
      end

      context 'when the service is operating normally' do
        before {
          travel_to Time.now

          allow(reporter).to receive(:ping?).and_return(true)
          allow(service_watcher).to receive(:check?).and_return(true)

          for _ in 0..100
            service_watcher.check_and_report
          end
        }

        it 'does not throttle reporting' do
          # force a new report
          service_watcher.instance_variable_set(:@was_up, false)
          expect(reporter).to receive(:report_up).and_return(true)
          expect(service_watcher.check_and_report).to be true
        end
      end
    end

    context 'when pinging of reporter fails' do
      it 'doesn\'t try to report' do
        expect(reporter).to receive(:ping?).and_return(false)
        expect(reporter).not_to receive(:report_up)
        expect(reporter).not_to receive(:report_down)

        expect(service_watcher.check_and_report).to be false
      end

      it 'does not throttle' do
        for _ in 0..100 do
          expect(service_watcher.check_and_report).not_to be nil
        end
      end
    end

    context 'when rate limiting is on shadow mode' do
      let(:rate_limit_config) { {'shadow_mode' => true} }

      before {
          travel_to Time.now

          allow(reporter).to receive(:ping?).and_return(true)
          allow(service_watcher).to receive(:check?) { rand() >= 0.5 }

          for _ in 0..100
            service_watcher.check_and_report
          end
        }

      it 'does not throttle' do
        service_watcher.instance_variable_set(:@was_up, false)
        expect(service_watcher).to receive(:check?).and_return(true)
        expect(reporter).to receive(:report_up).and_return(true)
        expect(service_watcher.check_and_report).to be true
      end
    end

    context 'when check is mocked' do
      let(:check_mocked) { true }
      it 'report up no matter if host is up or down' do
        expect(reporter).to receive(:ping?).and_return(true)
        expect(reporter).to receive(:report_up).and_return(true)
        expect(service_watcher.check_and_report).to be true
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
