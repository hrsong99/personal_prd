# Local Cloud SQL Proxy Access

This setup lets a local machine connect to Podo Cloud SQL databases through Docker containers running the Google Cloud SQL Auth Proxy.

The proxy handles the GCP-side secure connection. Database clients still need the actual MySQL username and password.

## One-time GCP setup

Log in with Application Default Credentials:

```bash
gcloud auth application-default login
```

Confirm the credential file exists:

```bash
ls -l ~/.config/gcloud/application_default_credentials.json
```

Set the quota project:

```bash
gcloud auth application-default set-quota-project podospeaking
```

## Docker Compose file

The local compose file is:

```text
~/Develop/script/docker-compose-podo-local.yaml
```

It defines four Cloud SQL Auth Proxy containers:

```text
stage -> podospeaking:asia-northeast3:podo-stage -> 127.0.0.1:3306
dev   -> podospeaking:asia-northeast3:podo-dev   -> 127.0.0.1:3307
prod  -> podospeaking:asia-northeast3:podo-prod  -> 127.0.0.1:3308
qa    -> podospeaking:asia-northeast3:podo-qa    -> 127.0.0.1:3309
```

The containers mount:

```text
~/.config/gcloud/application_default_credentials.json
```

inside the container as:

```text
/credentials.json
```

The compose services use:

```yaml
restart: unless-stopped
```

After they are started once, they should restart automatically when Docker Desktop starts.

## Start Docker Desktop

If Docker is not running, this command will fail:

```text
failed to connect to the docker API at unix:///Users/johnsong/.docker/run/docker.sock
```

Start Docker Desktop:

```bash
open -a Docker
```

Wait until Docker is running, or check with:

```bash
docker info
```

If `docker info` still fails, Docker Desktop may still be starting. Wait 30-60 seconds and try again.

## Start the proxies

```bash
docker compose -f ~/Develop/script/docker-compose-podo-local.yaml up -d
```

Check status:

```bash
docker compose -f ~/Develop/script/docker-compose-podo-local.yaml ps
```

View logs:

```bash
docker compose -f ~/Develop/script/docker-compose-podo-local.yaml logs -f
```

Stop the proxies:

```bash
docker compose -f ~/Develop/script/docker-compose-podo-local.yaml down
```

## DBeaver setup

Create a normal MySQL connection.

Use these host and port values:

```text
stage:
  Host: 127.0.0.1
  Port: 3306

dev:
  Host: 127.0.0.1
  Port: 3307

prod:
  Host: 127.0.0.1
  Port: 3308

qa:
  Host: 127.0.0.1
  Port: 3309
```

Use the actual MySQL database username and password. The Cloud SQL proxy does not replace database authentication.

## Port conflicts

If local MySQL is already using `3306`, the stage proxy may fail to start.

In that case, change the left side of the stage port mapping in `~/Develop/script/docker-compose-podo-local.yaml`:

```yaml
ports:
  - "127.0.0.1:13306:3306"
```

Then connect DBeaver to:

```text
Host: 127.0.0.1
Port: 13306
```

## Production caution

The production database is exposed locally on `127.0.0.1:3308` when the proxy is running. Be careful that local apps, scripts, and DBeaver connections do not accidentally point to production.
