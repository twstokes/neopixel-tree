const dgram = require("dgram");
const fs = require("fs");
const http = require("http");
const path = require("path");
const url = require("url");

const UDP_PORT = 8733;
const HTTP_PORT = process.env.PORT || 3000;
const PIXEL_COUNT = 106;
const UDP_BUFFER_SIZE = 512;
const DEFAULT_DELAY_MS = 5;
const RAINBOW_DEFAULT_DELAY = 100;
const RAINBOW_CYCLE_DELAY = 20;
const THEATER_CHASE_DELAY = 200;

const COMMANDS = {
  OFF: 0,
  BRIGHTNESS: 1,
  PIXEL_COLOR: 2,
  FILL_COLOR: 3,
  FILL_PATTERN: 4,
  RAINBOW: 5,
  RAINBOW_CYCLE: 6,
  THEATER_CHASE: 7,
  RESET_INFO: 253,
  UPTIME: 254,
  READBACK: 255,
};

const startTime = Date.now();
const udp = dgram.createSocket("udp4");
const publicDir = path.join(__dirname, "public");

let brightness = 255;
let activeAnimation = null;
let lastBroadcast = 0;
let pendingBroadcast = false;

const rawPacket = Buffer.alloc(UDP_BUFFER_SIZE);
let latestPacket = {
  command: 0,
  data: Buffer.alloc(0),
  dataLen: 0,
  repeat: false,
};

const pixels = new Array(PIXEL_COUNT).fill(null).map(() => ({
  r: 0,
  g: 0,
  b: 0,
}));

const sseClients = new Set();

udp.on("message", (msg, rinfo) => {
  if (!msg || !msg.length) return;
  const command = msg[0];

  if (command === COMMANDS.READBACK) {
    sendReadback(rinfo);
    return;
  }

  if (command === COMMANDS.RESET_INFO) {
    sendResetInfo(rinfo);
    return;
  }

  if (command === COMMANDS.UPTIME) {
    sendUptime(rinfo);
    return;
  }

  msg.copy(rawPacket, 0, 0, Math.min(msg.length, rawPacket.length));

  latestPacket = {
    command,
    data: msg.slice(1),
    dataLen: msg.length - 1,
    repeat: false,
  };

  const repeat = processCommand(command, latestPacket.data);
  latestPacket.repeat = repeat;
});

udp.on("listening", () => {
  const addr = udp.address();
  console.log(`UDP server listening on ${addr.address}:${addr.port}`);
});

udp.bind(UDP_PORT);

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url);
  if (parsedUrl.pathname === "/events") {
    return handleEventStream(req, res);
  }

  const requested =
    parsedUrl.pathname === "/"
      ? path.join(publicDir, "index.html")
      : path.join(publicDir, parsedUrl.pathname);

  const filepath = path.normalize(requested);
  const allowedPrefix = publicDir.endsWith(path.sep)
    ? publicDir
    : `${publicDir}${path.sep}`;
  if (
    filepath !== publicDir &&
    filepath !== publicDir + path.sep &&
    !filepath.startsWith(allowedPrefix)
  ) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(filepath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    const ext = path.extname(filepath).toLowerCase();
    const type = mimeType(ext);
    res.writeHead(200, { "Content-Type": type });
    res.end(data);
  });
});

server.listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on http://localhost:${HTTP_PORT}`);
});

setInterval(runAnimationFrame, DEFAULT_DELAY_MS);
setInterval(() => {
  if (pendingBroadcast) broadcastState(true);
}, 50);

function mimeType(ext) {
  switch (ext) {
  case ".js":
    return "application/javascript";
  case ".css":
    return "text/css";
  case ".html":
    return "text/html";
  case ".json":
    return "application/json";
  default:
    return "text/plain";
  }
}

function handleEventStream(_req, res) {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  res.write("\n");
  sseClients.add(res);
  res.on("close", () => sseClients.delete(res));
  broadcastState(true, res);
}

function broadcastState(force = false, target) {
  const now = Date.now();
  if (!force && now - lastBroadcast < 50) {
    pendingBroadcast = true;
    return;
  }
  const payload = JSON.stringify({
    pixels: pixels.map(applyBrightness),
    brightness,
    command: latestPacket.command,
    repeat: latestPacket.repeat,
  });
  const message = `data: ${payload}\n\n`;
  if (target) {
    target.write(message);
  } else {
    sseClients.forEach((client) => client.write(message));
  }
  lastBroadcast = now;
  pendingBroadcast = false;
}

function applyBrightness(color) {
  const scale = brightness / 255;
  return {
    r: Math.round(color.r * scale),
    g: Math.round(color.g * scale),
    b: Math.round(color.b * scale),
  };
}

function stopAnimation() {
  activeAnimation = null;
}

function processCommand(command, data) {
  switch (command) {
  case COMMANDS.OFF:
    stopAnimation();
    clearStrip();
    broadcastState(true);
    break;
  case COMMANDS.BRIGHTNESS:
    stopAnimation();
    brightnessCmd(data);
    break;
  case COMMANDS.PIXEL_COLOR:
    stopAnimation();
    pixelColorCmd(data);
    break;
  case COMMANDS.FILL_COLOR:
    stopAnimation();
    fillColorCmd(data);
    break;
  case COMMANDS.FILL_PATTERN:
    stopAnimation();
    fillPatternCmd(data);
    break;
  case COMMANDS.RAINBOW:
    return rainbowCmd(data);
  case COMMANDS.RAINBOW_CYCLE:
    return rainbowCycleCmd(data);
  case COMMANDS.THEATER_CHASE:
    return theaterChaseCmd(data);
  default:
    break;
  }
  return false;
}

function brightnessCmd(data) {
  if (!data || data.length !== 1) return;
  brightness = data[0];
  broadcastState(true);
}

function pixelColorCmd(data) {
  if (!data || data.length !== 4) return;
  const offset = data[0];
  if (offset >= PIXEL_COUNT) return;
  setPixelColor(offset, data[1], data[2], data[3]);
  broadcastState();
}

function fillColorCmd(data) {
  if (!data || data.length !== 3) return;
  fillStrip(data[0], data[1], data[2]);
  broadcastState();
}

function fillPatternCmd(data) {
  if (!data || data.length < 4) return;
  const numColors = data[0];
  if (data.length - 1 !== numColors * 3) return;
  if (numColors > PIXEL_COUNT) return;
  const colors = [];
  for (let i = 0; i < numColors; i++) {
    const idx = 1 + i * 3;
    colors.push({
      r: data[idx],
      g: data[idx + 1],
      b: data[idx + 2],
    });
  }

  for (let i = 0; i < PIXEL_COUNT; i++) {
    const c = colors[i % numColors];
    setPixelColor(i, c.r, c.g, c.b);
  }
  broadcastState();
}

function rainbowCmd(data) {
  if (!data || data.length < 1) return false;
  const repeat = Boolean(data[0]);
  const wait =
    data.length === 3 ? unpackDelay(data[1], data[2]) : RAINBOW_DEFAULT_DELAY;
  activeAnimation = {
    name: "rainbow",
    wait,
    repeat,
    j: 0,
    nextFrame: 0,
  };
  return repeat;
}

function rainbowCycleCmd(data) {
  if (!data || data.length !== 1) return false;
  const repeat = Boolean(data[0]);
  activeAnimation = {
    name: "rainbow_cycle",
    wait: RAINBOW_CYCLE_DELAY,
    repeat,
    j: 0,
    nextFrame: 0,
  };
  return repeat;
}

function theaterChaseCmd(data) {
  if (!data || data.length !== 4) return false;
  const repeat = Boolean(data[0]);
  const color = { r: data[1], g: data[2], b: data[3] };
  activeAnimation = {
    name: "theater_chase",
    wait: THEATER_CHASE_DELAY,
    repeat,
    q: 0,
    cycle: 0,
    color,
    nextFrame: 0,
  };
  return repeat;
}

function runAnimationFrame() {
  if (!activeAnimation) return;
  const now = Date.now();
  if (now < activeAnimation.nextFrame) return;

  if (activeAnimation.name === "rainbow") {
    doRainbowFrame(activeAnimation);
  } else if (activeAnimation.name === "rainbow_cycle") {
    doRainbowCycleFrame(activeAnimation);
  } else if (activeAnimation.name === "theater_chase") {
    doTheaterChaseFrame(activeAnimation);
  }
}

function doRainbowFrame(state) {
  for (let i = 0; i < PIXEL_COUNT; i++) {
    const c = wheel((i + state.j) & 255);
    setPixelColor(i, c.r, c.g, c.b);
  }
  state.j = (state.j + 1) % 256;
  if (!state.repeat && state.j === 0) {
    stopAnimation();
  }
  state.nextFrame = Date.now() + state.wait;
  broadcastState();
}

function doRainbowCycleFrame(state) {
  const limit = 256 * 5;
  for (let i = 0; i < PIXEL_COUNT; i++) {
    const c = wheel(((i * 256) / PIXEL_COUNT + state.j) & 255);
    setPixelColor(i, c.r, c.g, c.b);
  }
  state.j = (state.j + 1) % limit;
  if (!state.repeat && state.j === 0) {
    stopAnimation();
  }
  state.nextFrame = Date.now() + state.wait;
  broadcastState();
}

function doTheaterChaseFrame(state) {
  clearStrip();
  for (let i = 0; i < PIXEL_COUNT; i += 3) {
    const idx = i + state.q;
    if (idx < PIXEL_COUNT) {
      setPixelColor(idx, state.color.r, state.color.g, state.color.b);
    }
  }

  state.q = (state.q + 1) % 3;
  if (state.q === 0) {
    state.cycle += 1;
    if (state.cycle >= 10 && !state.repeat) {
      stopAnimation();
    } else if (state.cycle >= 10 && state.repeat) {
      state.cycle = 0;
    }
  }
  state.nextFrame = Date.now() + state.wait;
  broadcastState();
}

function setPixelColor(offset, r, g, b) {
  if (offset < 0 || offset >= PIXEL_COUNT) return;
  pixels[offset] = {
    r: gammaCorrect(r),
    g: gammaCorrect(g),
    b: gammaCorrect(b),
  };
}

function fillStrip(r, g, b) {
  for (let i = 0; i < PIXEL_COUNT; i++) {
    setPixelColor(i, r, g, b);
  }
}

function clearStrip() {
  fillStrip(0, 0, 0);
}

function gammaCorrect(value) {
  const gamma = 2.8;
  const normalized = Math.max(0, Math.min(255, value));
  return Math.round(Math.pow(normalized / 255, gamma) * 255);
}

function wheel(pos) {
  let wheelPos = 255 - pos;
  if (wheelPos < 85) {
    return { r: 255 - wheelPos * 3, g: 0, b: wheelPos * 3 };
  }
  if (wheelPos < 170) {
    wheelPos -= 85;
    return { r: 0, g: wheelPos * 3, b: 255 - wheelPos * 3 };
  }
  wheelPos -= 170;
  return { r: wheelPos * 3, g: 255 - wheelPos * 3, b: 0 };
}

function unpackDelay(high, low) {
  return ((high & 0xff) << 8) | (low & 0xff);
}

function sendReadback(rinfo) {
  udp.send(rawPacket, 0, UDP_BUFFER_SIZE, rinfo.port, rinfo.address);
}

function sendResetInfo(rinfo) {
  const reason = Buffer.from("SIM_RST_POWERON");
  udp.send(reason, 0, Math.min(reason.length, UDP_BUFFER_SIZE), rinfo.port, rinfo.address);
}

function sendUptime(rinfo) {
  const uptime = Buffer.from(String(Date.now() - startTime));
  udp.send(uptime, 0, Math.min(uptime.length, UDP_BUFFER_SIZE), rinfo.port, rinfo.address);
}
