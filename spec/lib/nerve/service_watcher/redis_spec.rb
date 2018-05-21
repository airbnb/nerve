require 'spec_helper'
require 'nerve/service_watcher/redis'

describe Nerve::ServiceCheck::RedisServiceCheck do
  let(:check) {
    {
      'type' => 'redis',
      'timeout' => 1.0,
      'host' => 'localhost',
      'port' => 6379,
      'rise' => 3,
      'fall' => 2,
    }
  }

  describe 'initialize' do
    it 'can successfully initialize' do
      described_class.new(check)
    end

    it 'requires minimum parameters' do
      %w[port].each do |req|
        check_without = check.dup
        check_without.delete(req)

        expect { described_class.new(check_without) }.to raise_error
      end
    end
  end

  describe 'check' do
    let(:service_check) { described_class.new(check) }
    let(:redis) { instance_double('Redis') }

    it 'checks the redis instance' do
      allow(Redis).to receive(:new).with(
        host: 'localhost', port: 6379, timeout: 1.0).and_return(redis)
      expect(redis).to receive(:ping)
      expect(redis).to receive(:exists).with('nerve-redis-service-check')
      expect(redis).to receive(:close)
      expect(service_check.check).to eq(true)
    end

    it 'closes the redis connection on error' do
      allow(Redis).to receive(:new).and_return(redis)
      expect(redis).to receive(:ping).and_raise(Redis::TimeoutError)
      expect(redis).to receive(:close)
      expect { service_check.check }.to raise_error
    end
  end
end
