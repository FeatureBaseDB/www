# Pilosa Website

The [Pilosa website](https://www.pilosa.com/) is built using [Hugo](https://gohugo.io/) and [Bootstrap 4](https://v4-alpha.getbootstrap.com/). It was designed by [Thirteen23](https://www.thirteen23.com/) and implemented in collaboration with [Vitamin T](https://vitamintalent.com/).

## System Requirements

* [Hugo](https://gohugo.io/)
* [Git](https://git-scm.com/)
* [AWS CLI](https://aws.amazon.com/cli/) (for deployment only)

## Usage

You can run it locally using `make`:

```
make server
```

This does two things. It retrieves the docs from the [main Pilosa repo](https://github.com/pilosa/pilosa) and then runs the hugo server with `--buildDrafts`, which displays drafts in the development server.

> Note that the docs do not get updated on future invocations of `make`, so you should run `make clean server` if you want to view the latest docs.

## Deployment

We use [continuous delivery](https://en.wikipedia.org/wiki/Continuous_delivery) for the website deployment. Travis CI builds every revision, as shown in the `.travis.yml` file in this repo. If the revision is in `master` or `staging`, it will be deployed to the relevant site:

* `master` branch is always deployed to [the production site](https://www.pilosa.com/) (via `make production deploy`).
* `staging` branch is always deployed to [the staging site](https://dc3kpxyuw05cb.cloudfront.net/) (via `make staging deploy`).

## Development

Please submit pull requests from private fork topic branches to the `master` branch. If the pull request includes changes that may cause risk when deploying to production, please push the changes directly to the `staging` branch, where they will be deployed automatically to the staging site.
