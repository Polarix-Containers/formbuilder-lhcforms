# Copyright 2025 Tommy Tran, Brian Banerjee
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



ARG NODE=22
ARG UID=200017
ARG GID=200017



FROM node:${NODE}-alpine AS build-base
ARG UID
ARG GID

RUN apk -U upgrade \
    && apk add git libstdc++ gojq \
    && npm update -g npm

RUN --network=none \
    addgroup -g ${GID} lhcforms \
    && adduser -u ${UID} --ingroup lhcforms --disabled-password --system lhcforms --home /home/lhcforms

USER lhcforms
WORKDIR /home/lhcforms
ENV NODE_ENV=production



FROM build-base AS build-formbuilder

RUN git clone https://github.com/LHNCBC/formbuilder-lhcforms/ \
    && cd formbuilder-lhcforms \
    && npm ci --include=dev \
#   https://github.com/LHNCBC/lforms-loader/blob/0eede528c0c1823b199d6fcea94dde1fb2c563d1/source/lformsLoader.js#L7
#   -> `const DEFAULT_LFORMS_SOURCE = '/lhcforms/';`
    && sed -i "s|\( DEFAULT_LFORMS_SOURCE \).*|\1= '/lhcforms/';|" node_modules/lforms-loader/source/lformsLoader.js \
    && npm run build



FROM build-base AS build-lhcforms

RUN git clone 'https://github.com/LHNCBC/lforms.git' lhcforms \
    && cd lhcforms \
    && npm ci --include=dev \
    && npm run build \
    && lhcforms_version="$(gojq --raw-output '.version' package.json)" \
    && mkdir -p /home/lhcforms/webroot/lhcforms \
    && mv dist/lforms "/home/lhcforms/webroot/lhcforms/$lhcforms_version" \
#   https://github.com/LHNCBC/lforms-loader/blob/0eede528c0c1823b199d6fcea94dde1fb2c563d1/source/lformsLoader.js#L89
    && echo ">lforms-$lhcforms_version.zip<" > /home/lhcforms/webroot/lhcforms/index.txt



FROM ghcr.io/polarix-containers/nginx:unprivileged-mainline-slim AS deploy

# https://github.com/nginx/docker-nginx-unprivileged/blob/a773d561b235f57f1c2417dbdef42348631ab0e6/entrypoint/docker-entrypoint.sh
ENV NGINX_ENTRYPOINT_QUIET_LOGS=1
USER root
RUN rm -rf /docker-entrypoint.d
USER nginx

COPY --from=build-formbuilder --chown=0:0 /home/lhcforms/formbuilder-lhcforms/dist/formbuilder-lhcforms /usr/share/nginx/html/formbuilder-lhcforms

COPY --from=build-lhcforms --chown=0:0 /home/lhcforms/webroot/lhcforms /usr/share/nginx/html/lhcforms

COPY nginx-default.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK NONE

EXPOSE 8080/tcp
LABEL org.opencontainers.image.authors="Tommy Tran <contact@tommytran.io>, Brian Banerjee <bbanerjee@bbanerjee.com>" \
      org.opencontainers.image.url="https://github.com/Polarix-Containers/formbuilder-lhcforms" \
      org.opencontainers.image.documentation="https://github.com/Polarix-Containers/formbuilder-lhcforms" \
      org.opencontainers.image.source="https://github.com/Polarix-Containers/formbuilder-lhcforms" \
      org.opencontainers.image.vendor="Polarix Containers" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.title="NLM Form Builder" \
      org.opencontainers.image.description="Web application to create and edit a FHIR Questionnaire resource" \
#     Inherited labels cannot be removed due to https://github.com/moby/moby/issues/3465, so clear them instead.
      org.opencontainers.image.created="" \
      org.opencontainers.image.version="" \
      org.opencontainers.image.revision="" \
#     The "maintainer" label is nonstandard and redundant with "org.opencontainers.image.authors".
      maintainer=""
