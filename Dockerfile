FROM python:3.14-slim@sha256:cea0e6040540fb2b965b6e7fb5ffa00871e632eef63719f0ea54bca189ce14a6

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    ANSIBLE_CONFIG=/workspace/ansible.cfg

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        git \
        make \
        openssh-client \
        rsync \
        sshpass \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-ci.in requirements-ci.txt requirements.yml /tmp/

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir --require-hashes --requirement /tmp/requirements-ci.txt \
    && python -m pip check

RUN mkdir -p /usr/share/ansible/collections \
    && ansible-galaxy collection install \
        -r /tmp/requirements.yml \
        -p /usr/share/ansible/collections

WORKDIR /workspace

CMD ["bash"]
