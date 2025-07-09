import consola from "consola";
import cors from "cors";
import express from "express";
import { parse } from "express-useragent";
import helmet from "helmet";
import morgan from "morgan";
import { compare, valid } from "semver";
import urlHelpers from "url";
import checkAlias from "./helpers/aliases";
import { Cache } from "./helpers/cache";
import proxyPrivateDownload from "./helpers/proxyDownload";
import * as middlewares from "./middlewares";

require("dotenv").config();

const app = express();

app.use(morgan("dev"));
app.use(helmet());
app.use(cors());
app.use(express.json());

const cache = new Cache({
  token: process.env.TOKEN || "",
  repository: process.env.REPOSITORY || "",
  account: process.env.ACCOUNT || "",
  url: process.env.URL || "",
  pre: process.env.PRE || "",
});

const shouldProxyPrivateDownload = cache.config.token.length > 0;

app.get("/version", async (req, res) => {
  const latest = await cache.loadCache();

  consola.log(`Request for latest version from ${req.useragent} | ${req.ip}`);

  if (!latest) return res.status(500).send("Latest not found.");

  return res.send({
    version: latest.version,
    notes: latest.notes,
    pub_date: latest.pub_date,
  });
});

app.get("/download", async (req, res) => {
  const userAgent = parse(req.headers["user-agent"] || "");
  const params = urlHelpers.parse(req.url, true).query;
  const isUpdate = params && params.update;

  let platform: string;

  if (userAgent.isMac && isUpdate) {
    platform = "darwin";
  } else if (userAgent.isMac && !isUpdate) {
    platform = "dmg";
  } else if (userAgent.isWindows) {
    platform = "exe";
  } else {
    platform = "";
  }

  consola.log(`Request for download from ${req.useragent} | ${req.ip}`);

  // Get the latest version from the cache
  const { platforms } = await cache.loadCache();

  const findPlatform = platforms.find((v) => v.platform == platform);

  if (!platform || !platforms || !findPlatform) {
    res.status(404).send("No download available for your platform!");
    return;
  }

  if (shouldProxyPrivateDownload) {
    await proxyPrivateDownload(findPlatform, cache.config.token, req, res);
    return;
  }

  res.writeHead(302, {
    Location: findPlatform.url,
  });

  res.end();
});

app.get("/download/:platform", async (req, res) => {
  const params = urlHelpers.parse(req.url, true).query;
  const isUpdate = params && params.update;

  let { platform } = req.params;

  if (platform === "mac" && !isUpdate) {
    platform = "dmg";
  }

  if (platform === "mac_arm64" && !isUpdate) {
    platform = "dmg_arm64";
  }

  consola.log(
    `Request for ${platform} download from ${req.useragent} | ${req.ip}`
  );

  // else platform = ''

  // Get the latest version from the cache
  const latest = await cache.loadCache();

  // Check platform for appropriate aliases
  platform = checkAlias(platform);

  // console.log(platform)

  const findPlatform = cache.cache.latest.platforms.find(
    (v) => v.platform == platform
  );

  // console.log(findPlatform)

  if (!platform) {
    res.status(500).send("The specified platform is not valid");
    return;
  }

  if (!latest.platforms || !platform) {
    res.status(404).send("No download available for your platform");
    return;
  }

  if (cache.config.token && cache.config.token.length > 0) {
    await proxyPrivateDownload(findPlatform, cache.config.token, req, res);
    return;
  }

  res.writeHead(302, {
    Location: latest.platforms.find((v) => v.platform == platform)?.url,
  });

  res.end();
});

app.get("/update/:platform/:version", async (req, res) => {
  const { platform: platformName, version } = req.params;

  if (!valid(version)) {
    res.status(500).send({
      error: "version_invalid",
      message: "The specified version is not SemVer-compatible",
    });

    return;
  }

  await cache.loadCache();

  const platform = checkAlias(platformName);

  const findPlatform = cache.cache.latest.platforms.find(
    (v) => v.platform == platform
  );

  if (!findPlatform) {
    res.status(500).send({
      error: "invalid_platform",
      message: "The specified platform is not valid",
    });

    return;
  }

  consola.log(
    `Request for ${platform} download of version ${version} from ${req.useragent} | ${req.ip}`
  );

  // Get the latest version from the cache
  const latest = await cache.loadCache();

  if (!latest.platforms || !findPlatform) {
    res.statusCode = 204;
    res.end();

    return;
  }

  // Previously, we were checking if the latest version is
  // greater than the one on the client. However, we
  // only need to compare if they're different (even if
  // lower) in order to trigger an update.

  // This allows developers to downgrade their users
  // to a lower version in the case that a major bug happens
  // that will take a long time to fix and release
  // a patch update.

  if (compare(latest.version, version) !== 0) {
    const { notes, pub_date } = latest;

    res.status(200).send({
      name: latest.version,
      notes,
      pub_date,
      url: shouldProxyPrivateDownload
        ? `${cache.config.url}/download/${platformName}?update=true`
        : findPlatform.url,
    });

    return;
  }

  res.statusCode = 204;
  res.end();
});

app.get("/overview", async (req, res) => {});

app.get("/releases", async (req, res) => {
  // Get the latest version from the cache
  const latest = await cache.loadCache();

  if (!latest.files || !latest.files.releases) {
    res.statusCode = 204;
    res.end();

    return;
  }

  consola.log(`Request for releases from ${req.useragent} | ${req.ip}`);

  const content = latest.files.releases;

  res.writeHead(200, {
    "content-length": Buffer.byteLength(content, "utf8"),
    "content-type": "application/octet-stream",
  });

  res.end(content);
});

app.use(middlewares.notFound);
app.use(middlewares.errorHandler);

export default app;
