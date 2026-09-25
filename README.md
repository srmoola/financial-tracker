# Financial Tracker

Rails 8.1 · PostgreSQL · Solid Queue · Tailwind CSS v4 · daisyUI 5

## Running with Docker (development)

```sh
docker compose up
```

Then open http://localhost:3000. If something else is already using port 3000, pick another host port:

```sh
WEB_PORT=3001 docker compose up
```

Services:

- `db`: PostgreSQL 18
- `web`: Rails server (runs `bin/rails db:prepare` on start)
- `css`: Tailwind watcher (`bin/rails tailwindcss:watch`)
- `jobs`: Solid Queue worker (`bin/jobs`)

Run commands inside the app container with `docker compose exec web bin/rails ...`.
After changing the Gemfile, rebuild with `docker compose build`.

## Production image

`Dockerfile` is the stock Rails production image (deployable with Kamal, see `config/deploy.yml`):

```sh
docker build -t financial_tracker .
```

## daisyUI

daisyUI is installed without Node.js, following https://daisyui.com/docs/install/rails/.
The plugin lives at `app/assets/tailwind/daisyui.mjs`. To upgrade, re-download it:

```sh
curl -sLo app/assets/tailwind/daisyui.mjs https://github.com/saadeghi/daisyui/releases/latest/download/daisyui.mjs
```
