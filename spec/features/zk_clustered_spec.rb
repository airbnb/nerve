require 'spec_helper'

describe Nerve do

  it "should announce the machine" do
    zookeeper.clustered.start
    zookeeper.clustered.wait_for_up

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

    zookeeper.clustered.start(:zoocfg => zk_options)
    zookeeper.clustered.wait_for_up

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
    zookeeper.clustered.start
    zookeeper.clustered.wait_for_up

    nerve.initialize_zk

    nerve.start
    nerve.wait_for_up

    zookeeper.clustered.stop(:signal => :KILL)
    nerve.process.wait(:timeout => 10)

    nerve.process.should_not be_running
  end

  it "should go down when one zookeeeper node is restarted" do
    zookeeper.clustered.start
    zookeeper.clustered.wait_for_up

    nerve.initialize_zk

    nerve.start
    nerve.wait_for_up

    zookeeper.clustered.restart_one
    nerve.process.wait(:timeout => 10)

    nerve.process.should_not be_running
  end


end
