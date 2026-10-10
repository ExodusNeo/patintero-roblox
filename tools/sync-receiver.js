// Receives script sources from Roblox Studio (POST JSON {path, source}) and writes them under the repo's src/.
// Usage: node sync-receiver.js <repoRoot>   — POST /done to stop.
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.resolve(process.argv[2]);
const SAFE = /^src\/(shared|server|client)\/[A-Za-z0-9_\/.]+\.luau$/;
let written = 0;

const server = http.createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    if (req.url === "/done") {
      res.end(`ok ${written}`);
      console.log(`done, wrote ${written} files`);
      server.close();
      return;
    }
    try {
      const { path: rel, source } = JSON.parse(body);
      if (typeof rel !== "string" || !SAFE.test(rel) || rel.includes("..") || typeof source !== "string") {
        res.statusCode = 400;
        return res.end("bad path");
      }
      const target = path.join(root, rel);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, source.replace(/\r\n/g, "\n"));
      written++;
      res.end("ok");
    } catch (e) {
      res.statusCode = 500;
      res.end(String(e));
    }
  });
});
server.listen(34873, "127.0.0.1", () => console.log("listening on 34873"));
