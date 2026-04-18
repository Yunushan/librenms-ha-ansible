FROM python:3.12-slim

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

RUN python -m pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir ansible-core ansible-lint yamllint

COPY requirements.yml /tmp/requirements.yml

RUN mkdir -p /usr/share/ansible/collections \
    && ansible-galaxy collection install \
        -r /tmp/requirements.yml \
        -p /usr/share/ansible/collections

WORKDIR /workspace

CMD ["bash"]
