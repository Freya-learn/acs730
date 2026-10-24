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
