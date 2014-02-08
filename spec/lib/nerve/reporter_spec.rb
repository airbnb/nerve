require 'spec_helper'

describe Nerve::Reporter do
  let(:subject) { {
      'zk_hosts' => ['zkhost1', 'zkhost2'],
      'zk_path' => 'zk_path',
      'instance_id' => 'instance_id',
      'host' => 'host',
      'port' => 'port'
    }
  }
  it 'can new_from_service' do
    expect(Nerve::Reporter).to receive(:new).with({
      'hosts' => ['zkhost1', 'zkhost2'],
      'path' => 'zk_path',
      'key' => "/instance_id_",
      'data' => {'host' => 'host', 'port' => 'port', 'name' => 'instance_id'},
    }).and_return('kerplunk')
    expect(Nerve::Reporter.new_from_service(subject)).to eq('kerplunk')
  end
  it 'can really construct an instance of Nerve::Reporter' do
    expect(Nerve::Reporter.new_from_service(subject).is_a?(Nerve::Reporter)).to eql(true)
  end
end

