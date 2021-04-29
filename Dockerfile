FROM ruby:2.5.7-slim-stretch

RUN apt-get update \
    && apt-get install git ssh jq curl dpkg-dev libgdbm-dev bison -yqq \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && mkdir -p /root/.ssh/ \
    && ssh-keyscan bitbucket.org > /root/.ssh/known_hosts

COPY script.sh .

CMD ["/bin/sh", "script.sh"]
