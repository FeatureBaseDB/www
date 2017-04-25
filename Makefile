.PHONY: public server upload reset-cache staging deploy

staging:
	$(eval HOST := www-staging.pilosa.com)
	$(eval CLOUDFRONT_ID := E3NZYVJQ5Z41XP)

server:
	hugo server --buildDrafts

public:
	hugo

upload:
	aws s3 sync --acl public-read public s3://$(HOST)

reset-cache:
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"

deploy: public upload reset-cache
