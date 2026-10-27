ARG BUILD_FROM=python:3.13-slim-bookworm
FROM ${BUILD_FROM}

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /opt/hermes-notifier

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY hermes_notifier ./hermes_notifier
COPY vendor ./vendor
COPY run.sh /run.sh
RUN chmod 0755 /run.sh

EXPOSE 8787

CMD ["/run.sh"]
