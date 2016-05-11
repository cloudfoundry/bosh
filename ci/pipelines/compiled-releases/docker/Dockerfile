FROM bosh/main-ruby-go

ENV PATH /opt/rubies/ruby-2.1.7/bin:$PATH

ADD install-bosh.sh /tmp/install-bosh.sh
RUN /tmp/install-bosh.sh && rm /tmp/install-bosh.sh
