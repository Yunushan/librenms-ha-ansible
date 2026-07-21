FROM python:3.12-slim@sha256:57cd7c3a7a273101a6485ba99423ee568157882804b1124b4dd04266317710de

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

COPY requirements-ci.txt requirements.yml /tmp/

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir --requirement /tmp/requirements-ci.txt \
    && python -m pip check

RUN mkdir -p /usr/share/ansible/collections \
    && ansible-galaxy collection install \
        -r /tmp/requirements.yml \
        -p /usr/share/ansible/collections

WORKDIR /workspace

CMD ["bash"]
