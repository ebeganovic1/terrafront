# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: export the Godot project to a static web build.
# Self-contained: pulls the matching engine and export templates itself, so a
# clean checkout builds identically without Godot installed on the host.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS builder

ARG GODOT_VERSION=4.7.2
ARG GODOT_RELEASE=stable
ENV GODOT_DIR=/opt/godot

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

# Engine binary, architecture matched to the build platform.
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) GODOT_ARCH=x86_64 ;; \
      arm64) GODOT_ARCH=arm64  ;; \
      *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}"; \
    mkdir -p "${GODOT_DIR}"; \
    curl -fSL --retry 3 -o /tmp/godot.zip \
      "${base}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.${GODOT_ARCH}.zip"; \
    unzip -q /tmp/godot.zip -d "${GODOT_DIR}"; \
    mv "${GODOT_DIR}"/Godot_v* "${GODOT_DIR}/godot"; \
    chmod +x "${GODOT_DIR}/godot"; \
    rm /tmp/godot.zip

# Export templates, installed where the headless editor expects them.
RUN set -eux; \
    base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}"; \
    curl -fSL --retry 3 -o /tmp/templates.tpz \
      "${base}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz"; \
    mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"; \
    unzip -q /tmp/templates.tpz -d /tmp/tpl; \
    mv /tmp/tpl/templates/* "/root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}/"; \
    rm -rf /tmp/templates.tpz /tmp/tpl

WORKDIR /project
COPY . .

# First pass imports resources, second pass produces the build.
# The import pass reports missing-resource errors on a cold cache; the export
# is the step whose exit code matters.
RUN set -eux; \
    mkdir -p builds/web; \
    "${GODOT_DIR}/godot" --headless --path . --import || true; \
    "${GODOT_DIR}/godot" --headless --path . --export-release "Web" builds/web/index.html; \
    test -s builds/web/index.html; \
    test -s builds/web/index.wasm

# ---------------------------------------------------------------------------
# Stage 2: serve the static build. No SharedArrayBuffer, no special headers.
# ---------------------------------------------------------------------------
FROM nginx:1.27-alpine AS runtime

RUN rm -f /etc/nginx/conf.d/default.conf
COPY docker/nginx.conf /etc/nginx/conf.d/terrafront.conf
COPY --from=builder /project/builds/web/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
