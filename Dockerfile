ARG NODE=22
ARG UID=200017
ARG GID=200017

FROM node:${NODE}-alpine
ARG UID
ARG GID

RUN apk -U upgrade \
    && apk add git libstdc++ \
    && npm update -g npm

RUN --network=none \
    addgroup -g ${GID} lhcforms \
    && adduser -u ${UID} --ingroup lhcforms --disabled-password --system lhcforms --home /home/lhcforms

USER lhcforms
WORKDIR /home/lhcforms

RUN git clone https://github.com/LHNCBC/formbuilder-lhcforms/ \
    && cd formbuilder-lhcforms \
    && npm audit fix --audit-level=none \
    && npm run build

WORKDIR /home/lhcforms/formbuilder-lhcforms

ENV NODE_OPTIONS=--max_old_space_size=4096

CMD [ "npm", "run", "start-public", "--", "--dist" ]
