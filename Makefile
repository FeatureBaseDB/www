.PHONY: public server upload reset-cache staging deploy clean

DOC_TAGS = master v0.4 v0.5 v0.6 v0.7 v0.8 v0.9 v0.10 v1.0 v1.1 v1.2 v1.3
DOC_TAG_DIRS = $(addprefix content/docs/,$(DOC_TAGS))
DOC_TAG_LATEST = v1.3
PILOSA_CLONE = $(PWD)/pilosa
DOC_NAMES = $(shell find content/docs/* -type f -exec basename {} \; | sort | uniq)
DOC_REDIRECTS = $(addprefix content/docs/,$(DOC_NAMES))
# BSD sed will not work. Use gsed if on MacOS (brew install gnome-sed)
SED := $(shell sed --version > /dev/null 2>&1 && echo sed || echo gsed )

production:
	$(eval HUGO_ENV := production)
	$(eval HOST := www.pilosa.com)
	$(eval CLOUDFRONT_ID := E2R5AYQQK6RFGD)
staging:
	$(eval HUGO_ENV := staging)
	$(eval HOST := www-staging.pilosa.com)
	$(eval CLOUDFRONT_ID := E3NZYVJQ5Z41XP)

content/docs: $(PILOSA_CLONE) $(DOC_TAG_DIRS) content/docs/latest
	@# $(DOC_REDIRECTS) is empty during the first run, so the prerequisite doesn't run.
	make $(DOC_REDIRECTS)

$(PILOSA_CLONE):
	git clone git://github.com/pilosa/pilosa.git $(PILOSA_CLONE)

$(DOC_TAG_DIRS):
	$(eval DOC_TAG := $(@:content/docs/%=%))
	git -C $(PILOSA_CLONE) --git-dir $(PILOSA_CLONE)/.git checkout $(DOC_TAG)
	mkdir -p $@
	# add last-updated times per file
	for f in `ls -1 $(PILOSA_CLONE)/docs/ | grep -v -i README`; do UPDATED="$$(git --git-dir $(PILOSA_CLONE)/.git log -1 --date=relative --format='%ad' -- docs/$$f)" ; CMD="1a updated = '$$UPDATED'" ; $(SED) "$$CMD" $(PILOSA_CLONE)/docs/$$f > $@/$$f;  done

content/docs/latest: content/docs/$(DOC_TAG_LATEST)
	cp -r content/docs/$(DOC_TAG_LATEST) $@

$(DOC_REDIRECTS):
	@echo +++ > $@
	@echo layout = \"redirect\" >> $@
	@echo +++ >> $@

server: content/docs
	hugo server --buildDrafts

public: content/docs
	HUGO_ENV=$(HUGO_ENV) hugo

upload:
	aws s3 sync --delete --acl public-read public s3://$(HOST)

reset-cache:
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"

deploy: public upload reset-cache

clean:
	rm -rf content/docs $(PILOSA_CLONE)
