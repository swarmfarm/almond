# use the official Bun image
# see all versions at https://hub.docker.com/r/oven/bun/tags
FROM oven/bun:1 AS base
WORKDIR /usr/src/app

# install dependencies into temp directory
# this will cache them and speed up future builds
FROM base AS install
RUN mkdir -p /temp/dev
COPY package.json bun.lock /temp/dev/
# Allow lockfile updates during the install stage
RUN cd /temp/dev && bun install

# install with --production (exclude devDependencies)
FROM base AS prod-install
RUN mkdir -p /temp/prod
COPY package.json bun.lock /temp/prod/
# Now we can use the frozen lockfile for production
RUN cd /temp/prod && bun install --frozen-lockfile --production

# copy node_modules from temp directory
# then copy all (non-ignored) project files into the image
FROM base AS prerelease
COPY --from=install /temp/dev/node_modules node_modules
COPY . .

# [optional] tests & build
ENV NODE_ENV=production

# Build the TypeScript code
FROM prerelease AS build
RUN bun run build

# copy production dependencies and built code into final image
FROM base AS release
COPY --from=prod-install /temp/prod/node_modules node_modules
COPY --from=build /usr/src/app/dist ./dist
COPY --from=prerelease /usr/src/app/package.json .

# run the app
USER bun
EXPOSE 5000/tcp
ENTRYPOINT [ "bun", "run", "start" ]
