require 'spec_helper'

describe Nerve::ServiceWatcher do
  describe 'initialize' do
    let(:service) { build(:service, :zookeeper) }

    it 'can successfully initialize' do
      Nerve::ServiceWatcher.new(service)
    end

    it 'requires minimum parameters' do
      %w[zk_hosts zk_path instance_id host port].each do |req|
        service_without = service.dup
        service_without.delete(req)

        expect { Nerve::ServiceWatcher.new(service_without) }.to raise_error
      end
    end
  end
end
