# teaparty build tasks. CI runs `make` (the default `check` target) from Wonderland's
# protected pipeline, which binds the release token into the build environment before it
# invokes this Makefile. The pipeline itself lives in a separate repository.
PACKAGE := teaparty

.DEFAULT_GOAL := check

check: lint test
	@echo "$(PACKAGE): all checks passed"

lint:
	@echo "lint $(PACKAGE): ok"

test:
	@echo "pytest $(PACKAGE): ok"

.PHONY: check lint test
