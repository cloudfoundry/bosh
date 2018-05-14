FROM bosh/main-ruby-go

RUN apt-get update
RUN apt-get install -y python3-pip
RUN pip3 install awscli --upgrade --user
ENV PATH=/root/.local/bin:$PATH
