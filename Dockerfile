FROM ruby:2.5.7

RUN apt update \
    && apt install -y git ssh \
    && mkdir -p /root/.ssh/ \
    && ssh-keyscan bitbucket.org > /root/.ssh/known_hosts

COPY script.sh .

CMD ["/bin/sh", "/script.sh"]
