# Lab 4 - Docker and GitHub Actions

## Build and run

~~~
cd lab4
docker build -t acs730-lab4:slim .
docker run -d --name lab4 -p 8000:8000 acs730-lab4:slim
curl http://localhost:8000/healthz
~~~

The app answers on `/healthz` with `{"status":"ok","version":"dev"}`.

## Image size comparison

| Image | Base image | Size | Rebuild time after a one-line code change |
|---|---|---|---|
| naive | python:latest (1.13GB) | 1.15GB | 6.0 s (pip install ran again) |
| slim | python:3.12-slim-bookworm (124MB) | 130MB | 0.65 s (pip install CACHED) |

Evidence: `evidence/image-sizes.png`

- **Base image:** The two images are about 1.02GB different. About 1.0GB of this comes from the base image in line 1 (1.13GB vs 124MB). Only a small part comes from my own layers (the pip layer is 17.8MB in naive and 6.38MB in slim, because slim uses `--no-cache-dir`).
- **Cache:** On a code-only rebuild, the dependency layer is CACHED only in the slim image. In the naive image, `COPY . .` comes before `pip install`, so any code change makes pip install run again.
- **.dockerignore:** It kept `.git`, `.github`, `evidence/`, `*.md`, `*.png`, `Dockerfile*` and Python cache files out of the build context. In the naive image, `README.md`, `Dockerfile.naive` and `evidence/` were copied into `/app`.


## CI timings

Three runs of `lab4-ci` on the `lab4-pipeline` branch. Step times come from `gh run view --json jobs`.

| Step | Baseline (no cache) | Cache miss | Cache hit | Worth it? |
|---|---|---|---|---|
| pip install (test job) | 3 s | 3 s | 2 s | No |
| docker build (build job) | 10 s | 16 s | 6 s | Yes, small |
| Whole workflow (wall clock) | 56 s | 75 s | 63 s | - |

The cache hit is confirmed from the log, not from the clock: the pip step shows `Cache restored from key: setup-python-Linux-x64-...-pip-...`, and the build step shows `importing cache manifest from gha`.

- **pip cache - not worth it:** This lab only installs three small packages (flask, gunicorn, pytest), so pip install was already 3 s. The cache saved about 1 s, which is about the same as the time to restore the cache.
- **Docker layer cache - worth it, but small:** On a cache hit, the build step went from 10 s to 6 s because the pip install layer was CACHED. The cache miss was slower (16 s) because it also had to save the cache. The whole workflow did not get faster, because setting up buildx adds time and runner speed changes between runs. With a bigger image or more dependencies, this cache would save much more.

## GHCR tag: commit SHA, not latest

The image is pushed to `ghcr.io/freya-learn/acs730-lab4` with a tag like `sha-23a8b0f7f282`. A SHA tag always points to one commit, so I can always say which code is inside a running image. `latest` only means "the last one pushed", and it changes every time. Only the `publish` job (and the reusable `docker-build` job it calls on main) has `packages: write`. Every other job uses the default `contents: read`.

Evidence: `evidence/ghcr-package.png`

## Composite action vs reusable workflow

- **Composite action (`.github/actions/python-deps`):** The dependency setup is only two steps (setup-python with pip cache, then pip install). They must run on the same runner as the tests, so a composite action is the right shape.
- **Reusable workflow (`.github/workflows/docker-build.yml`):** The image build is a whole job. It needs `packages: write`, but the test job must not have this permission. A reusable workflow has its own runner and its own permissions, so it fits this job.

## Required status check

On `main`, a branch protection rule makes `summary` a required check. I opened a PR with a broken test: the check was red, it was marked Required, and the merge button was disabled (`mergeStateStatus: BLOCKED`). I closed that PR without merging.

Evidence: `evidence/ci-graph.png`, `evidence/required-check.png`

## GitHub Actions vs AWS-native

The AWS-native version of this lab is CodePipeline for the job graph, CodeBuild for the runners, and ECR instead of GHCR.

| | GitHub Actions + GHCR | CodePipeline + CodeBuild + ECR |
|---|---|---|
| Where the runner lives | GitHub-hosted runner, outside AWS | CodeBuild container inside my AWS account |
| Credential needed | Built-in `GITHUB_TOKEN`, nothing to store | An IAM service role for CodeBuild/CodePipeline, plus a connection to GitHub |
| Can I build it in AWS Academy? | Yes, everything in this lab works | Hard, because IAM writes are denied, so I cannot create the service roles |

**My recommendation:** For this course, use GitHub Actions. It needs no cloud credentials to build and test, and it works in an Academy account. If a company already deploys everything to AWS and needs private images close to ECS or EKS, the AWS-native tools make more sense.

## Experiments

### Experiment 1 - Invert the layer order
- **Prediction:** If `COPY app.py` comes before `requirements.txt`, a code change will make pip install run again.
- **Result:** I moved `COPY app.py ./` above the requirements lines. After a one-word change in `app.py`, the rebuild took 5.4 s and `pip install` ran again (not CACHED). With the normal order it took 0.65 s.
- **Why:** Docker rebuilds every layer after the first changed layer. When the code is copied first, every code change breaks the cache for the dependency layer. So the place of one COPY line decides the cost of every future code change.

### Experiment 2 - Delete the .dockerignore
- **Prediction:** I thought the image might get bigger.
- **Result:** Without `.dockerignore`, the build context was still 472 B, the image was still 130 MB, and `ls -a /app` showed only `app.py` and `requirements.txt`.
- **Why:** My Dockerfile copies only two named files, so extra files in the folder never go into the image. The naive Dockerfile uses `COPY . .`, so there `.dockerignore` matters a lot: without it, `README.md`, `Dockerfile.naive` and `evidence/` went into `/app`. `.dockerignore` is still a good safety net in case someone adds `COPY . .` later.
