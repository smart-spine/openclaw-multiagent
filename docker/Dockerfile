FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    tini \
  && rm -rf /var/lib/apt/lists/*

ARG OPENCLAW_VERSION=2026.2.19-2
RUN npm install -g "openclaw@${OPENCLAW_VERSION}" clawhub

RUN mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node /.clawhub

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
CMD ["openclaw", "gateway", "--bind", "lan", "--port", "18789", "--allow-unconfigured"]
