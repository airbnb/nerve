.PHONY: http tcp zoo1 zoo2 zoo3 stat1 stat2 stat3 stat stat nerve bignerve

http:
	rackup -p 8080 test.ru

tcp:
	./tcp_server.rb

zoo1:
	ZOOCFGDIR=$(PWD)/zoo1 /usr/local/Cellar/zookeeper/3.4.5/libexec/bin/zkServer.sh start-foreground

zoo2:
	ZOOCFGDIR=$(PWD)/zoo2 /usr/local/Cellar/zookeeper/3.4.5/libexec/bin/zkServer.sh start-foreground

zoo3:
	ZOOCFGDIR=$(PWD)/zoo3 /usr/local/Cellar/zookeeper/3.4.5/libexec/bin/zkServer.sh start-foreground

stat1:
	echo --- zoo1: ---
	echo stat | nc 127.0.0.1 2181
	echo

stat2:
	echo --- zoo2: ---
	echo stat | nc 127.0.0.1 3181
	echo

stat3:
	echo --- zoo3: ---
	echo stat | nc 127.0.0.1 4181
	echo

stat: stat1 stat2 stat3

nerve: ../nerve.jar
	java -jar ../nerve.jar --config config.json

bignerve: ../nerve.jar
	java -jar ../nerve.jar --config config_big.json

../nerve.jar:
	cd ..; warble
