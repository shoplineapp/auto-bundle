FROM alpine:3.13.5

RUN apk add git openssh \
    && mkdir -p /root/.ssh/ \
    && ssh-keyscan bitbucket.org > /root/.ssh/known_hosts

COPY script.sh .

CMD ["/bin/sh", "/script.sh"]
