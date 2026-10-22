.PHONY: check package install

check:
	./scripts/check.sh

package:
	./scripts/package.sh

install:
	./scripts/install-dev.sh "$(RETAIL_DIR)"
