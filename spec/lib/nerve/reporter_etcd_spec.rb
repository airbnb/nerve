require 'spec_helper'
require 'nerve/reporter/etcd'

describe Nerve::Reporter::Etcd do
  let(:subject) { {
      'etcd_host' => 'etcdhost1',
      'etcd_port' => 4001,
      'etcd_path' => '/path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }
  it 'actually constructs an instance' do
    expect(Nerve::Reporter::Etcd.new(subject).is_a?(Nerve::Reporter::Etcd)).to eql(true)
  end
end

