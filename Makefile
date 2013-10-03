REL = $(shell ruby -r./lib/nerve/version -e 'puts Nerve::VERSION')

build: nerve.jar

push:
	curl -X PUT -F file=@nerve.jar https://ssspy.d.musta.ch/nerve/nerve-dev.jar

push-release:
	curl -X PUT -F file=@nerve.jar https://ssspy.d.musta.ch/nerve/nerve-$(REL).jar

nerve.jar:
	warble jar

.PHONY: build push push-release
