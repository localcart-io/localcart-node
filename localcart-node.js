import fs from "node:fs";
import path from "node:path";
import { v4 as uuidv4 } from "uuid";
import axios from "axios";
import { WebPubSubClient } from "@azure/web-pubsub-client";
import { exec } from "node:child_process";

let BACKEND_BASE_URL = "https://dev.localcart.io";
let DEVICE_KEY = process.env.DEVICE_KEY;
let HEARTBEAT = false;
let GROUP = null;

var log_file = fs.createWriteStream(path.join(process.cwd(), "run.log"), {
  flags: "a",
});

if (!DEVICE_KEY) {
  const DEVICE_KEY_FILE = path.join(process.cwd(), "device-id.txt");
  if (fs.existsSync(DEVICE_KEY_FILE)) {
    DEVICE_KEY = fs.readFileSync(DEVICE_KEY_FILE, "utf-8").trim();
  } else {
    DEVICE_KEY = uuidv4();
    fs.writeFileSync(DEVICE_KEY_FILE, DEVICE_KEY, "utf-8");
  }
}

const api = axios.create({
  baseURL: BACKEND_BASE_URL,
  timeout: 15000,
  headers: { "Content-Type": "application/json" },
});

function log(first_message, second_message = null, third_message = null) {
  const now = new Date().toISOString().slice(0, 19).replace("T", " ");
  log_file.write(
    now +
      " " +
      first_message +
      (second_message ? " " + second_message : "") +
      (third_message ? " " + third_message : "") +
      "\n"
  );
  console.log(
    now,
    first_message,
    second_message ? " " + second_message : "",
    third_message ? " " + third_message : ""
  );
}

async function negotiate() {
  const r = await api.post("/api/node/negotiate", { deviceKey: DEVICE_KEY });
  return r.data;
}

async function heartbeat(client) {
  HEARTBEAT = true;
  client.sendToGroup(GROUP, "heartbeat", "text");

  setTimeout(function () {
    heartbeat(client);
  }, 5000);
}

async function sendHeartbeat() {
  api.post("/api/node/heartbeat", { deviceKey: DEVICE_KEY });
}

async function action(actionId) {
  let result = await api.post("/api/node/action", {
    deviceKey: DEVICE_KEY,
    actionId: actionId,
  });
  let command = result.data;
  log("Executing command:", command);

  exec(command, async (error, stdout, stderr) => {
    if (error) {
      log("Execution error:", error.message);
      return;
    }

    if (stderr) {
      log("Error:", stderr);
    }

    log("Command output:", stdout);

    result = await api.post("/api/node/action/executed", {
      deviceKey: DEVICE_KEY,
      actionId: actionId,
      result: stdout,
    });

    console.log(result.data);
  });
}

(async () => {
  log("Negotiating for access...");
  let negotiateData;
  while (true) {
    try {
      negotiateData = await negotiate();
      break;
    } catch (e) {
      const code = e?.response?.status;
      const data = e?.response?.data;
      log("Negotiate denied: ", code);
      await new Promise((r) => setTimeout(r, 5000));
    }
  }
  GROUP = negotiateData.group;
  log("Negotiated successfully: allowed to listen to group " + GROUP);
  log("Connecting to PubSub service...");

  const client = new WebPubSubClient({
    getClientAccessUrl: async () => {
      const negotiateData = await negotiate();
      return negotiateData.url;
    },
  });

  client.on("connected", async (e) => {
    log("Connected!");

    await client.joinGroup(GROUP);
    await client.sendToGroup(GROUP, "joining", "json");
    if (!HEARTBEAT) await heartbeat(client);
  });

  client.on("disconnected", (e) => {
    log("Disconnected: ", e.message);
  });

  client.on("stopped", () => {
    log("Client stopped");
    client.start();
  });

  client.on("group-message", (e) => {
    //log("Group message from " + e.message.fromUserId + ": " + e.message.data);

    let command = e.message.data.trim().split(/\s+/)[0];
    let arg1 = e.message.data.trim().split(/\s+/)[1];
    switch (command) {
      case "heartbeat":
        log("Heartbeat detected from " + e.message.fromUserId);
        sendHeartbeat();
        break;
      case "joining":
        log("Joining detected from " + e.message.fromUserId);
        break;
      case "action":
        log("Action detected");
        action(arg1);
        break;
      default:
        log("Unknown command detected: " + command);
    }
  });

  client.on("server-message", (e) => {
    log("Server message:", e);
  });
  await client.start();
})();
