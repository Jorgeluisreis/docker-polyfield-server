<div align="center">
  <img src="https://i.imgur.com/de0AmoU.png" alt="Polyfield Server Docker" width="400"/>
  <br>
  <a href="https://github.com/Jorgeluisreis/docker-polyfield-server/releases">
    <img src="https://img.shields.io/github/v/release/Jorgeluisreis/docker-polyfield-server?logo=github" alt="Release">
  </a>
  <a href="https://github.com/Jorgeluisreis/docker-polyfield-server/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Jorgeluisreis/docker-polyfield-server" alt="License">
  </a>
  <a href="https://github.com/Jorgeluisreis/docker-polyfield-server/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/Jorgeluisreis/docker-polyfield-server/CI.yaml?branch=main" alt="CI">
  </a>
  <a href="https://hub.docker.com/r/jluisreis/polyfield-server">
    <img src="https://img.shields.io/docker/pulls/jluisreis/polyfield-server?logo=docker" alt="Docker Pulls">
  </a>
  <a href="https://hub.docker.com/r/jluisreis/polyfield-server">
    <img src="https://img.shields.io/docker/image-size/jluisreis/polyfield-server/latest" alt="Image Size">
  </a>
</div>

---

# Polyfield Server Docker

Docker image that provides a Polyfield server that automatically downloads and configures on startup.

## Main Features

- Automatic download and setup of the latest Polyfield server
- Customizable server settings (match type, maps, player limits, etc.)
- Real-time log monitoring system with per-map event logs
- Automatic restart scheduling (daily or interval-based)
- Timezone support
- Docker Compose ready

---

## Quick Start

Create a `docker-compose.yml` file:

```yaml
services:
  polyfield-server:
    image: ghcr.io/jorgeluisreis/docker-polyfield-server:latest
    container_name: polyfield
    environment:
      - region=My Server Region
      - starting_port=7777
      - username=Host
      - admin_code=123456
    volumes:
      - ./data:/root/.config/unity3d/Mohammad Alizade/Polyfield/
    ports:
      - "7777:7777/udp"
    restart: unless-stopped
```

Run the server:

```bash
docker-compose up -d
```

View logs:

```bash
docker-compose logs -f
```

For detailed configuration options and advanced settings, see the **[Wiki Documentation](https://github.com/Jorgeluisreis/docker-polyfield-server/wiki)**.

---

## Contributing

Contributions are welcome! Please read our **[Contributing Guidelines](CONTRIBUTING.md)** for details on our workflow, commit conventions, and how to submit pull requests.

---
