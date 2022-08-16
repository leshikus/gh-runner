FROM ubuntu:latest

ENV RUNNER_VERSION=2.294.0
ENV MINICONDA_VERSION="latest"
ENV DEBIAN_FRONTEND="noninteractive"
ENV CONDA=/build-runner/miniconda3

RUN groupadd -g 142 docker

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libicu-dev \
    git \
    wget \
    jq \
    bzip2 \
    tar \
    binutils \
    docker.io

WORKDIR /build-runner

RUN useradd -m --uid 1001 ghrunner
RUN chown ghrunner:ghrunner /build-runner
RUN usermod -aG docker ghrunner

USER ghrunner

RUN mkdir -p /home/ghrunner/.docker
COPY config.json /home/ghrunner/.docker/

RUN curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

RUN curl -o Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh -L https://repo.anaconda.com/miniconda/Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh

RUN tar xzf actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

RUN bash Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh -b -p $CONDA

RUN mkdir -p /home/ghrunner/.m2/
COPY settings.xml /home/ghrunner/.m2/

RUN $CONDA/bin/conda init

COPY entrypoint.sh .

ENTRYPOINT ["bash", "/build-runner/entrypoint.sh"]
#ENTRYPOINT ["bash"]
