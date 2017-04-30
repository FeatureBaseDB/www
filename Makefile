.PHONY: public server upload reset-cache staging deploy

production:
	$(eval HUGO_ENV := production)
	$(eval HOST := www.pilosa.com)
	$(eval CLOUDFRONT_ID := E2R5AYQQK6RFGD)
staging:
	$(eval HUGO_ENV := staging)
	$(eval HOST := www-staging.pilosa.com)
	$(eval CLOUDFRONT_ID := E3NZYVJQ5Z41XP)

server:
	hugo server --buildDrafts

public:
	hugo

upload:
	aws s3 sync --delete --acl public-read public s3://$(HOST)

reset-cache:
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"

deploy: public upload reset-cache
