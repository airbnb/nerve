require 'spec_helper'

describe Nerve::Reporter::Zookeeper do
  let(:subject) { {
      'zk_hosts' => ['zkhost1', 'zkhost2'],
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }
  it 'can new_from_service' do
    expect(Nerve::Reporter::Zookeeper).to receive(:new).with({
      'hosts' => ['zkhost1', 'zkhost2'],
      'path' => 'zk_path',
      'key' => "/instance_id_",
      'data' => {'host' => 'host', 'port' => 'port', 'name' => 'instance_id'},
    }).and_return('kerplunk')
    expect(Nerve::Reporter::Zookeeper.new_from_service(subject)).to eq('kerplunk')
  end
  it 'actually constructs an instance' do
    expect(Nerve::Reporter::Zookeeper.new_from_service(subject).is_a?(Nerve::Reporter::Zookeeper)).to eql(true)
  end
end

