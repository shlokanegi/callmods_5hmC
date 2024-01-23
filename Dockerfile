FROM ubuntu:20.04
LABEL maintainer="Shloka Negi, shnegi@ucsc.edu"

# Prevent dpkg from trying to ask any questions, ever
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    gcc \
    git \
    make \
    bzip2 \
    tabix \
    python3 \
    python3-pip \
    libncurses5-dev \
    libncursesw5-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    autoconf \
    build-essential \
    pkg-config \
    apt-transport-https software-properties-common dirmngr gpg-agent \
    && rm -rf /var/lib/apt/lists/*
    
## install R
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    r-base \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('ggplot2', 'dplyr'))"

# Add scripts
RUN mkdir -p /opt/scripts
ADD plot-dist.R /opt/scripts

# Install modkit
RUN mkdir -p /home/apps
WORKDIR /home/apps
RUN wget https://github.com/nanoporetech/modkit/releases/download/v0.2.0/modkit_v0.2.0_centos7_x86_64.tar.gz && \
    tar -xvzf modkit_v0.2.0_centos7_x86_64.tar.gz

RUN mkdir -p /home/data
WORKDIR /home/data

ENV PATH="/home/apps/dist:${PATH}"