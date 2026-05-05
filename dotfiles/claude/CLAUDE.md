- for git, always use `master` as the default branch name (not `main`) — when initializing new repos, run `git init -b master`
- use echo -e so the colors will display properly on Makefiles
- if making a django project, use always latest LTS (web search it)
- for python/django testing we use pytest
- use always Makefiles to keep a common way to run projects, astro, next, python, django... make start should always exist as a main start point, start would point to remove api if it makes sense, and make start-local will point to local api (again if it makes sense because we are on a frontend project for example)
- for tmux session management in Makefiles, always add both:
    - `make tmux` — attaches to or creates the project's main session (use this, not `make start`)
    - `make tmux-new-session` — attaches via a grouped session (`tmux new-session -t <name> \; set-option destroy-unattached on`) so a second client shares windows/panes but navigates independently; falls back to creating the main session if it doesn't exist
- on django projects:
    - use uuid4 as primary keys, including users
    - use uv for dependencies, but dont use uv run, use uv to install deps system wide inside the docker
- for backend code we use docker compose meant to deploy to coolify (check context7 and websearch about sevice variables on env vars to easy the deploy to coolify)
- in python prefer httpx to requests
- always use **PydanticAI** when interacting with LLMs
- for Django + HTMX projects, use **Tailwind CSS + DaisyUI** for UI (via CDN for prototypes, built for production)
- **i18n capitalization**: For Spanish, Catalan, and French translations, use **sentence case** (only capitalize the first word and proper nouns). English can use Title Case for headings/buttons. Example: "Se registran" not "Se Registran".

## Coolify: Dockerfile vs Docker Compose deploys

- **Single-service backend? Prefer the Dockerfile resource type, not Compose.** Coolify's "Application → Dockerfile" mode supports **blue-green deployments** (build the new container, health-check it, then swap traffic — zero-downtime, instant rollback). The Docker-Compose application buildpack does NOT do blue-green: deploys stop the running stack and bring up the new one, leaving a brief gap where requests 502.
- Pick Compose only when you genuinely need multi-service orchestration in the same resource (sidecars, init containers, a tightly-coupled stack). Plausible/Grafana/Sentry/Postgres should each be **their own Coolify resource**, not co-deployed with the app — that way the app stays a Dockerfile resource and keeps blue-green.
- Cost of Dockerfile mode: settings that would live in `docker-compose.yml` (`stop_grace_period`, `restart`, healthcheck, env-var defaults) move into the Coolify UI or into Dockerfile directives (`HEALTHCHECK`, `STOPSIGNAL`). One less file to maintain; harder to grep all config in one place.
- Migration path: starting Dockerfile-only and switching to Compose later when you add a sidecar is straightforward — point Coolify at the new compose file and re-deploy. Going the other way (Compose → Dockerfile to gain blue-green) means re-creating the resource, which loses Coolify's deployment history for that resource.

## Coolify Docker Compose Key Findings

- **Don't use `expose` or port mappings for web interface** - Coolify's Traefik routes internally via Docker network, not through host ports. Port mappings interfere with routing.
- **Only port-map services needing direct access** - e.g., streaming ports (8000), SFTP (2022), databases if needed externally.
- **Set port in Coolify UI** - Use "Port Exposes" field in dashboard to tell Traefik which internal port to route to (e.g., 80).
- **Traefik labels — depends on resource type:**
  - **Docker Compose application buildpack** (the usual case): Coolify auto-generates Traefik labels. **Don't add custom ones** — they conflict with the auto-generated `traefik.http.services.<name>.loadbalancer.server.port` and cause Bad Gateway.
  - **Raw Compose Resource** (deploying a service stack directly): Coolify does NOT auto-generate routing labels. You must add `traefik.enable=true`, `traefik.http.routers.<name>.rule=Host(\`...\`)`, `traefik.http.routers.<name>.entryPoints=http` yourself.
- **Coolify env var substitution syntax (compose file):**
  - `${VARIABLE}` — editable in Coolify UI; deploy fails if unset
  - `${VARIABLE:-default}` — optional, falls back to default
  - `${VARIABLE:?default}` — **required**, default is the UI hint, deploy refuses to start if user clears it
  - `${VARIABLE:?}` — required, no default
- **Magic environment variables** (auto-generated and persisted across deployments):
  - `SERVICE_PASSWORD_<NAME>` / `SERVICE_PASSWORD_<NAME>_64` — random password
  - `SERVICE_USER_<NAME>` — random 16-char username
  - `SERVICE_FQDN_<NAME>` — hostname, e.g. `app.example.com`
  - `SERVICE_URL_<NAME>` — full URL with scheme
  - `SERVICE_BASE64_<NAME>` / `_64` / `_128` — random base64 string
  - **Identifier gotcha:** identifiers with `_` cannot specify ports. Use hyphens: `SERVICE_URL_BACKEND-API_8080` ✓, `SERVICE_URL_BACKEND_API_8080` ✗.
  - Requires Coolify v4.0.0-beta.411+ for compose-file support.
- **Shared variables across services in a stack** (referenced inside compose file or env vars):
  - `{{team.NODE_ENV}}` — team-wide
  - `{{project.NODE_ENV}}` — project-wide
  - `{{environment.NODE_ENV}}` — environment-wide (production/staging)
- **Build vs Runtime variable flags:** mark anything the running container needs but the build doesn't (API keys, JWT secrets, DSNs) as **Runtime-only** in the UI. Keeps secrets out of `/artifacts/build-time.env` and out of the build context entirely.
- **Docker Build Secrets** for build-time-only secrets (e.g. private package tokens during `RUN`): enable "Use Docker Build Secrets" + add `# syntax=docker/dockerfile:1` to Dockerfile. Coolify rewrites `RUN` with `--mount=type=secret`; value never lands in image layers or `docker history`.
- **Don't define custom Docker networks** — defining `networks:` in your compose puts containers on two networks at once, causing intermittent 504 Gateway Timeouts as Traefik flips IPs non-deterministically.
- **Cross-stack networking** — services in different compose stacks can't reach each other by service name by default. Enable "Connect to Predefined Network" on the resource; the hostname becomes `<service>-<resource_uuid>`.
- **App must listen on 0.0.0.0** - Not localhost, or Traefik can't reach it.
- **Coolify-specific compose extensions:**
  - `exclude_from_hc: true` on a service — Coolify skips it for stack health (use for one-off migration jobs).
  - `is_directory: true` on a volume — create empty directory.
  - `content:` field on a volume — file with inline content (or use top-level `configs`).
- **For Raw Compose Resource** — Coolify still auto-injects `coolify.managed=true`, `coolify.applicationId=<n>`, `coolify.type=application` if absent.
- **502 Bad Gateway on small VPS is usually swap, not config.** Check `free -m` first; many VPS providers ship swap disabled.
- Docs: https://coolify.io/docs/knowledge-base/docker/compose
- Docs: https://coolify.io/docs/knowledge-base/environment-variables
- Docs: https://coolify.io/docs/applications/build-packs/docker-compose
- Docs: https://coolify.io/docs/troubleshoot/applications/bad-gateway
- to update homepage (gethomepage.dev) run: docker pull ghcr.io/gethomepage/homepage:latest

## Docker Signal Handling for Fast Deployments

When using `sh -c "command"` in docker-compose, the shell becomes PID 1 and doesn't forward SIGTERM to the child process. This causes 30-second timeouts on every container stop.

**Fix:** Always use `exec` to replace the shell with the main process:
```yaml
# BAD - shell swallows SIGTERM, 30s timeout
command: sh -c "python manage.py runworker"

# GOOD - exec replaces shell, signals forwarded correctly
command: sh -c "exec python manage.py runworker"
```

**Also add `stop_grace_period`** to limit wait time:
```yaml
services:
  worker:
    command: sh -c "exec python manage.py runworker"
    stop_grace_period: 10s
```

**For entrypoint/start scripts:** Always end with `exec "$@"` not just `"$@"`.


## PydanticAI + Langfuse Integration

Two components work together for full tracing:

1. **Langfuse `@observe` decorator** - Captures function input/output (args, return value)
2. **PydanticAI `instrument=True`** - Captures model calls, tool usage, token costs

### Required Setup

```python
from langfuse import observe
from pydantic_ai import Agent

# Call once at startup - sets up OpenTelemetry TracerProvider
from enacast_backend.common.langfuse_config import init_langfuse
init_langfuse()

# Agent with instrumentation for model details
agent = Agent(model, output_type=MyOutput, instrument=True)

# Decorator on main function for input/output tracing
@observe(name="my_agent")
def run_my_agent(url: str) -> MyOutput:
    return agent.run_sync(prompt).output
```

### Environment Variables
- `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_BASE_URL`
- OTLP endpoint: `{LANGFUSE_BASE_URL}/api/public/otel/v1/traces`

### Packages Required
- `langfuse>=3.11.0`
- `opentelemetry-sdk`
- `opentelemetry-exporter-otlp-proto-http`

### Troubleshooting: "agent run" with no input/output
If traces show "agent run" but input=null and output=undefined, you're missing the `@observe` decorator. PydanticAI instrumentation alone doesn't capture function-level I/O - only model calls.

### WARNING: never pass Django models / ORM objects to an `@observe()` function
`@observe()` defaults to `capture_input=True, capture_output=True`. Its serializer recurses into Django model state (field descriptors, `_state.db`, related managers) and allocates gigabytes — workers OOM (SIGKILL 9) before the function body runs. Always use `@observe(capture_input=False, capture_output=False)` for any function that takes a Django model (`Episode`, etc.), and attach sanitized trace data inside via `start_as_current_generation(input=...)` + `generation.update(output=...)`.

### WARNING: `langfuse.openai.OpenAI` buffers streamed responses
The Langfuse-instrumented OpenAI wrapper accumulates the full streamed body to write a complete trace span at the end — this defeats any client-side byte cap on the response. Use the native `from openai import OpenAI` for the client that hits the API, and do tracing via explicit `start_as_current_generation(...)` context managers. Preview models (e.g. Gemini 3.1 flash-lite-preview) can ignore `max_tokens` and stream indefinitely with structured outputs; always enforce a client-side byte cap via `stream=True` + a size check.

  PydanticAI WebFetchTool Limitations:
  - WebFetchTool() respects robots.txt - will be blocked by sites that disallow crawlers
  - For blocked sites, use Playwright instead to bypass restrictions
  - Playwright also renders JavaScript (SPA sites, dynamic content)

  Playwright for Agents:
  - Use sync API: from playwright.sync_api import sync_playwright
  - Mobile user-agent often gets simpler pages: is_mobile=True
  - Pre-fetch content with Playwright, then pass text to agent (don't give agent Playwright tool directly)
  - Can intercept network requests to find audio streams

  Agent Best Practices:
  - Always preserve original language - tell agent explicitly not to translate
  - For logo/image URLs - tell agent to ONLY use URLs found in content (prevents hallucination)
  - Use --dry-run option in management commands for safe testing
  - Model format: google-gla:gemini-3-flash-preview (provider:model-name)
