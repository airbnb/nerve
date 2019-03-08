require 'spec_helper'
require 'nerve/service_watcher/noop'

describe Nerve::ServiceCheck::NoopServiceCheck do
  let(:check) {
    {
      'type' => 'noop',
    }
  }


  describe 'check' do
    let(:service_check) { described_class.new(check) }

    it 'is always true' do
      expect(service_check.check).to eq(true)
    end
  end
end

