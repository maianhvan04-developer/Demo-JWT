FROM node:22.23.2-alpine

ENV NODE_ENV=production
WORKDIR /app
COPY --chown=node:node package*.json ./
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm ci --omit=dev --no-audit --no-fund --prefer-offline
COPY --chown=node:node src ./src

USER node
EXPOSE 4000
CMD ["npm", "start"]
