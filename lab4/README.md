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
