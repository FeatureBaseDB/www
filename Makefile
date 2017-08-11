.PHONY: public server upload reset-cache staging deploy clean

DOC_TAGS = v0.4 v0.5 v0.6
DOC_TAG_DIRS = $(addprefix content/docs/,$(DOC_TAGS))
DOC_TAG_LATEST = v0.6
PILOSA_CLONE = $(PWD)/pilosa
DOC_NAMES = $(shell find content/docs/* -type f -exec basename {} \; | sort | uniq)
DOC_REDIRECTS = $(addprefix content/docs/,$(DOC_NAMES))

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
	mkdir -p content/docs
	cp -r $(PILOSA_CLONE)/docs $@

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
