build: nerve.jar

push:
	curl -X PUT -F file=@nerve.jar https://ssspy.d.musta.ch/nerve/nerve-dev.jar

nerve.jar:
	warble jar

.PHONY: build push
