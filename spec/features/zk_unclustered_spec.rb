require 'spec_helper'

describe Nerve do

  it "should announce the machine" do
    zookeeper.single.start
    zookeeper.single.wait_for_up

    nerve.initialize_zk

    nerve.start
    nerve.wait_for_up

    until_timeout(10) do
      zookeeper.children(nerve.machine_check_path).should_not be_empty
    end
  end

  it "should announce the machine after a sudden restart" do
    # Ensure that sessions expire rather quickly.
    zk_options = {
      :minSessionTimeout => 2000,
      :maxSessionTimeout => 2000
    }

    zookeeper.single.start(:zoocfg => zk_options)
    zookeeper.single.wait_for_up

    nerve.initialize_zk

    nerve.start
    nerve.wait_for_up

    until_timeout(10) do
      zookeeper.children(nerve.machine_check_path).should_not be_empty
    end

    nerve.restart(:signal => :KILL)
    nerve.wait_for_up

    # Wait for the ephemeral node to possibly disappear.
    sleep 5

    until_timeout(10) do
      zookeeper.children(nerve.machine_check_path).should_not be_empty
    end
  end

  it "should go down with zookeeeper" do
    zookeeper.single.start
    zookeeper.single.wait_for_up

    nerve.initialize_zk

    nerve.start
    nerve.wait_for_up

    zookeeper.single.stop(:signal => :KILL)
    nerve.process.wait(:timeout => 10)

    nerve.process.should_not be_running
  end

end