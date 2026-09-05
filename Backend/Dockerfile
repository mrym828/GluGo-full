FROM python:3.13-slim

WORKDIR /app

# libgomp1: lightgbm's wheel dynamically links OpenMP at runtime and this
# slim base image doesn't ship it — without it, importing lightgbm crashes.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# torch's default PyPI wheel bundles the full NVIDIA CUDA toolkit (several
# GB) even though this app only ever runs CPU inference (map_location='cpu'
# in prediction.py, no .cuda() anywhere) — pull the CPU-only build instead,
# then let requirements.txt fill in everything else. pip sees torch already
# satisfied at the pinned version and skips reinstalling it.
RUN pip install --no-cache-dir torch==2.9.1 --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x docker-entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["./docker-entrypoint.sh"]
