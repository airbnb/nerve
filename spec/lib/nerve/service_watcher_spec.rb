require 'spec_helper'

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
  end
end
