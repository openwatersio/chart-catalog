SHELL := /bin/bash
WORK ?= work
OUT ?= out/charts
SOURCE ?= noaa-enc

export WORK OUT SOURCE

.PHONY: all fetch bake catalog validate publish test clean
.DEFAULT_GOAL := catalog

all: validate

fetch: $(WORK)/cells.json
$(WORK)/cells.json:
	scripts/fetch.sh

bake: $(WORK)/archives.json
$(WORK)/archives.json: $(WORK)/cells.json
	scripts/bake.sh

# Tiles are optional here: without a bake the catalog still lists every chart and links the
# upstream ENC zips, which is all a self-processing app needs.
catalog: $(WORK)/cells.json
	scripts/catalog.sh

validate: catalog
	scripts/validate.sh

publish: validate
	scripts/publish.sh

test:
	tests/test.sh

clean:
	rm -rf $(WORK) out
