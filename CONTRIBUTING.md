# Contributing Guidelines #

Thanks for contributing to SmartStack!
If you're opening a new PR, please ask for a merge into our `pull_requests` branch -- *not* `master`.
This will allow us avoid a back-and-forth by quickly accepting your PR and then making minor changes or doing testing before merging into `master`.

## Writing Checks ##

We welcome additional service checks into the core of nerve.
However, your checks must follow a few guidelines or they will not be accepted:

* be sure to respect timeouts; checks that do not time-out will not be accepted
* do NOT shell out; this becomes very expensive when done frequently
* use well-tested, stable, core libraries whenever possible
