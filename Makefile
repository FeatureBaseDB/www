.PHONY: public server upload reset-cache staging deploy clean

production:
	$(eval HUGO_ENV := production)
	$(eval HOST := www.pilosa.com)
	$(eval CLOUDFRONT_ID := E2R5AYQQK6RFGD)
staging:
	$(eval HUGO_ENV := staging)
	$(eval HOST := www-staging.pilosa.com)
	$(eval CLOUDFRONT_ID := E3NZYVJQ5Z41XP)

content/docs:
	$(eval PILOSA_CLONE := $(shell mktemp -d))
	git clone git://github.com/pilosa/pilosa.git $(PILOSA_CLONE)
	git -C $(PILOSA_CLONE) --git-dir $(PILOSA_CLONE)/.git checkout docs
	cp -r $(PILOSA_CLONE)/docs content/docs

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
	rm -rf content/docs
