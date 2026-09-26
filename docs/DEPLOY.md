# Deploying TERRAFRONT behind nginx and cloudflared

What you are putting on the server is a folder of static files. There is no backend,
no database and no server-side state. The build is single-threaded, so it needs no
cross-origin isolation and no COOP/COEP response headers.

| Item | Size |
| --- | --- |
| `index.wasm` uncompressed | about 40 MB |
| `index.wasm` gzipped | about 10 MB |
| Game data pack | 92 KB |
| Docker image | 126 MB |

Almost the entire payload is the engine, it is identical for every visitor, and it is
served immutable. Getting it cached at Cloudflare's edge matters more than anything
else in this document.

## Option A: container behind your existing nginx

This is the recommended path if nginx already fronts other sites on the box.

### 1. Build and run

~~~bash
git clone https://github.com/ebeganovic1/terrafront
cd terrafront
git checkout web-port
docker compose up -d --build
~~~

Compose binds the container to `127.0.0.1:8080`, so it is not reachable from the
internet directly. Only nginx and cloudflared can see it.

Confirm it is alive before touching nginx:

~~~bash
curl -s http://127.0.0.1:8080/healthz          # expect: ok
curl -sI http://127.0.0.1:8080/index.wasm | grep -i content-type
~~~

The build downloads roughly 1.2 GB of Godot export templates and needs a few GB of
free disk. On a small VPS, build on your laptop and ship the image instead:

~~~bash
docker save terrafront:latest | gzip | ssh you@server 'gunzip | docker load'
~~~

### 2. nginx server block

~~~nginx
server {
    listen 80;
    server_name terrafront.example.com;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # The container already gzips. Streaming avoids buffering a 10 MB
        # response to a temp file on every cold request.
        gzip off;
        proxy_buffering off;
    }
}
~~~

Then `nginx -t && systemctl reload nginx`.

TLS is not configured here on purpose. Cloudflare terminates it at the edge and
cloudflared reaches this block over loopback, so a plain `listen 80` bound to the
tunnel is correct. Do not open port 80 to the internet in your firewall.

### 3. cloudflared

~~~bash
cloudflared tunnel login
cloudflared tunnel create terrafront
cloudflared tunnel route dns terrafront terrafront.example.com
~~~

`/etc/cloudflared/config.yml`:

~~~yaml
tunnel: <TUNNEL-ID>
credentials-file: /etc/cloudflared/<TUNNEL-ID>.json

ingress:
  - hostname: terrafront.example.com
    service: http://127.0.0.1:80
    originRequest:
      httpHostHeader: terrafront.example.com
  - service: http_status:404
~~~

~~~bash
cloudflared service install
systemctl enable --now cloudflared
~~~

If you would rather skip nginx entirely, point the tunnel straight at the container
with `service: http://127.0.0.1:8080` and delete the server block. The container
already serves correct types, compression and cache headers on its own.

## Option B: plain static files, no Docker

Build on your machine and copy the folder up.

~~~bash
godot --headless --path . --export-release "Web" builds/web/index.html
rsync -av --delete builds/web/ you@server:/var/www/terrafront/
~~~

~~~nginx
server {
    listen 80;
    server_name terrafront.example.com;
    root /var/www/terrafront;
    index index.html;

    types { application/wasm wasm; }

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types application/wasm application/javascript text/javascript text/html application/json;

    location / { try_files $uri $uri/ /index.html; }

    location ~* \.(wasm|pck)$ {
        add_header Cache-Control "public, max-age=31536000, immutable" always;
    }

    location = /index.html {
        add_header Cache-Control "no-cache" always;
    }
}
~~~

Check your nginx ships a wasm MIME mapping with `grep wasm /etc/nginx/mime.types`.
Recent builds do. The explicit `types` block above covers older ones. Serving
WebAssembly as `application/octet-stream` disables streaming compilation and makes
startup noticeably slower.

## Cloudflare settings that actually matter

**Cache the wasm explicitly.** This is the one that bites. `.wasm` is not in
Cloudflare's default list of cached file extensions, so without a rule every single
visitor pulls the full engine from your origin. Add a Cache Rule for the hostname
matching URI paths ending in `.wasm` or `.pck`, set it to Eligible for cache, and
leave edge TTL following origin headers, which already say immutable for a year.
Verify with `cf-cache-status` below.

**Enable Brotli** under Speed, Optimization. It compresses the engine better than
gzip and the saving is large at this payload size.

**Turn Rocket Loader off** for this hostname. It reorders and defers script execution
and is a known way to break WebAssembly loaders. Auto Minify on JavaScript is also
worth leaving off here.

## Verify the live site

~~~bash
curl -sI https://terrafront.example.com/index.wasm \
  | grep -i 'content-type\|content-encoding\|cache-control\|cf-cache-status'
~~~

You want `application/wasm`, a `br` or `gzip` encoding, the immutable cache header,
and `cf-cache-status: HIT` on the second request. A persistent `MISS` or `DYNAMIC`
means the Cache Rule above is not matching.

Then open the page and confirm the terrain and bottom bar appear after the splash.

## Updating

~~~bash
git pull
docker compose up -d --build
~~~

The engine payload is content-addressed per build, so returning players pick up a new
version without a stale cache. If you ever need to force it, purge the hostname in
Cloudflare.

## Known limits

Desktop browsers only. The window minimum is 1100x850 and every control is
mouse-button or drag based, so there is no touch or mobile support. There is also no
save system, so a refresh restarts the match.
