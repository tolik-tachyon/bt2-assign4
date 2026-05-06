import { createServer, IncomingMessage, ServerResponse } from "http";
import { createReadStream, existsSync, statSync } from "fs";
import { extname, join, normalize } from "path";

const PORT = 8080;
const ROOT = join(process.cwd(), "frontend");

const mimeTypes: Record<string, string> = {
    ".html": "text/html",
    ".js":   "text/javascript",
    ".css":  "text/css",
    ".json": "application/json",
    ".png":  "image/png",
    ".jpg":  "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif":  "image/gif",
    ".txt":  "text/plain",
};

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
    let urlPath = req.url || "/";
    if (urlPath === "/") urlPath = "/index.html";

    const filePath = normalize(join(ROOT, urlPath)).replace(/^(\.\.[\/\\])+/, "");

    if (!existsSync(filePath) || statSync(filePath).isDirectory()) {
        res.statusCode = 404;
        res.end("Not Found");
        return;
    }

    const ext = extname(filePath);
    const contentType = mimeTypes[ext] || "application/octet-stream";
    res.setHeader("Content-Type", contentType);

    const stream = createReadStream(filePath);
    stream.pipe(res);

    stream.on("error", () => {
        res.statusCode = 500;
        res.end("Server Error");
    });
})

server.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});
