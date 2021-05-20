FROM alpine

LABEL maintainer="Yi Siqi <yisiqi@inspur.com>"

ARG KUBE_VER=v1.21.1
ARG KUBE_ARC=amd64
ARG HELM_VER=v3.5.4
ARG HELM_ARC=amd64

RUN wget https://storage.googleapis.com/kubernetes-release/release/$KUBE_VER/bin/linux/$KUBE_ARC/kubectl -P /usr/local/bin \
  && chmod +x /usr/local/bin/kubectl \
  && cd /tmp \
  && wget https://get.helm.sh/helm-$HELM_VER-linux-$HELM_ARC.tar.gz \
  && tar -xzvf helm-$HELM_VER-linux-amd64.tar.gz \
  && mv ./linux-amd64/helm /usr/local/bin \
  && chmod +x /usr/local/bin/helm \
  && cd - \
  && rm -rf /tmp/* \
  && apk add --update --no-cache curl git bash \
  # && helm init --client-only --skip-refresh \
  && helm plugin install --version master https://github.com/sonatype-nexus-community/helm-nexus-push.git \
  && sed -i 's/set -ueo pipefail/set -eo pipefail/g' /root/.helm/plugins/helm-nexus-push.git/push.sh

ADD bin /root/.helm/plugins/helm-nexus.git/bin
ADD main.sh /root/.helm/plugins/helm-nexus.git
ADD plugin.yaml /root/.helm/plugins/helm-nexus.git
ADD LICENSE /root/.helm/plugins/helm-nexus.git
