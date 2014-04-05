build: nerve.jar

nerve.jar:
	jruby -S warble jar

.PHONY: build push
