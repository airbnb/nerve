require 'spec_helper'
require 'nerve/reporter/zookeeper'

describe Nerve::Reporter::Zookeeper do
  let(:subject) { {
      'zk_hosts' => ['zkhost1', 'zkhost2'],
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }
  it 'actually constructs an instance' do
    expect(Nerve::Reporter::Zookeeper.new(subject).is_a?(Nerve::Reporter::Zookeeper)).to eql(true)
  end
end

