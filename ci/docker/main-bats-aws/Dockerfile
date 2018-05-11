FROM bosh/main-ruby-go

RUN \
  apt-get update \
  && apt-get install -y \
    python3-pip \
  && export LC_ALL=C \
  && pip3 install awscli --upgrade --user

ENV PATH=/root/.local/bin:$PATH
