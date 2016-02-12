# Contributing Guidelines #

Thanks for contributing to SmartStack!

If you are opening a new PR, please ask for a merge into the `master` branch.

## Writing Reporters ##
Nerve supports *pluggable* reporters, which means that you can easily add
a reporter by making your own gem that contains your reporter available for
require at ``nerve/reporter/#{name.downcase}``. If you do this please do
submit a PR with a link to your gem/repo and we can reference it from the
README.

In general it is preferred to keep reporters that require specific dependencies
out of nerve because that way you can select the version of dependencies that
you need (for example if you have a particular version of the docker api or
etcd). That being said, if your reporter has no external dependencies
(e.g. files) or is extremely common (e.g. zookeeper, etcd), we may choose to
support it in the repo itself.

## Writing Checks ##

We welcome additional service checks into the core of nerve.
However, your checks must follow a few guidelines or they will not be accepted:

* be sure to respect timeouts; checks that do not time-out will not be accepted
* do NOT shell out; this becomes very expensive when done frequently
* use well-tested, stable, core libraries whenever possible
