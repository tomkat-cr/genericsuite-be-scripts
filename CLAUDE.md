# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**genericsuite-be-scripts** is an NPM-published collection of bash scripts that powers the development, testing, and deployment of Python-based backend APIs (Chalice, FastAPI, or Flask) and the GenericSuite packages. Consumer projects install it via `npm install genericsuite-be-scripts` and reference scripts through `node_modules/genericsuite-be-scripts/scripts/`.

It is part of a larger ecosystem of GenericSuite projects, including web frontends (genericsuite-fe, genericsuite-fe-ai), backend APIs (genericsuite-be, genericsuite-be-ai) and mobile packages (genericsuite-mobile). For more information about the GenericSuite ecosystem, see the [GenericSuite Basecamp](https://github.com/tomkat-cr/genericsuite-basecamp).

## Common Commands

All commands below are for **consumer projects** that have installed this package. When working in this repo itself, scripts live at `scripts/` directly.

### Development
```bash
make run              # Start local app with Docker DB (local_db config)
make local-db-up      # Start local DB Docker containers only
make local-db-down    # Stop local DB Docker containers
make local-db-logs    # View local DB container logs
make link_gs_libs     # Symlink local GenericSuite libs for development
make create-supad     # Create super admin user (use CHECKING=1 STAGE=dev make create-supad to preview)
make agents_md_link        # Link AGENTS.md and CLAUDE.md files
```

### Testing & Quality
```bash
make test             # Full test run (starts MongoDB Docker if needed)
make test_only        # Run tests without Docker setup
make lint             # Run linter
make types            # Run type checker
make coverage         # Run coverage report
make format           # Auto-format code
make format_check     # Check formatting without modifying
make pycodestyle      # PEP 8 style check
make qa               # Run lint + types + format_check + pycodestyle
make sast-test             # Run SAST testing
```

### AWS Deployment
```bash
make deploy_qa        # Deploy to QA (SAM + Lambda)
make deploy_staging   # Deploy to staging
make deploy_prod      # Deploy to production
make deploy_ec2       # Deploy to EC2 (use CICD_MODE=0 ACTION=run STAGE=qa TARGET=ec2)
make deploy_dynamodb  # Deploy DynamoDB (use CICD_MODE=0 ACTION=run STAGE=qa TARGET=dynamodb)
```

### Database Setup
```bash
make generate_postgres_dev_sql   # Generate SQL for Postgres dev tables
make create_postgres_dev_tables  # Create Postgres dev tables
make generate_mysql_dev_sql      # Generate SQL for MySQL dev tables
make create_mysql_dev_tables     # Create MySQL dev tables
make mongo_backup                # Backup MongoDB (use STAGE=qa BACKUP_DIR=/path)
make mongo_restore               # Restore MongoDB (use STAGE=qa RESTORE_DIR=/path)
```

### SSL & DNS
```bash
make create_ssl_certs  # Create and copy self-signed SSL certs
make local_dns         # Start local DNS server
make local_dns_down    # Stop local DNS server
```

### Publishing (this repo)
```bash
make pre-publish  # Validate before NPM publish
make publish      # Publish to NPM
UPDATE_SNAPSHOTS=1 make publish  # Publish with updated test snapshots
make pypi-build   # Build Python dist
make pypi-publish # Publish to PyPI
```

### Cloudflare Tunnel (HTTPS local dev alternative)
```bash
make cf-tunnel-login   # Authenticate with Cloudflare
make cf-tunnel-create  # Create tunnel
make cf-tunnel-run     # Run tunnel
```

## Architecture

### Script Organization

Scripts are organized by concern under `scripts/`:

| Directory | Purpose |
|-----------|---------|
| `scripts/` (root) | Cross-cutting utilities: PEM wrapper, test runner, logging, local IP, container engine detection |
| `scripts/aws/` | Chalice/AWS config, test runner, stack operations, Lambda URL retrieval |
| `scripts/aws_big_lambda/` | Large Lambda deployments via SAM — Docker images (AL2/Alpine), SAM templates, API Gateway runner |
| `scripts/aws_dynamodb/` | DynamoDB CloudFormation generation and deployment |
| `scripts/aws_ec2_elb/` | EC2 + ELB deployment, ECR image creation |
| `scripts/aws_cf_processor/` | Generic CloudFormation deployment + LocalStack testing |
| `scripts/aws_secrets/` | AWS Secrets Manager + KMS key management |
| `scripts/cryptography/` | Encryption seed generation |
| `scripts/dependency-sync/` | Syncs Poetry dependencies into Dockerfiles |
| `scripts/dns/` | Local DNS server (dnsmasq via Docker) |
| `scripts/local_db/` | Docker Compose stack for local MongoDB, DynamoDB, PostgreSQL, MySQL |
| `scripts/mongo/` | MongoDB backup and restore |
| `scripts/secure_local_server/` | NginX-based HTTPS reverse proxy for local dev |
| `scripts/sql_db/` | PostgreSQL and MySQL CloudFormation generation, SQL schema files |
| `.chalice/` | Chalice project templates (included in NPM package) |

### Key Scripts

- **`scripts/run_pem.sh`** — Central wrapper for Python environment managers (uv, pipenv, poetry). Routes install/update/lint/test commands to the correct tool based on project config.
- **`scripts/aws/run_aws.sh`** — Framework-aware backend AWS operations. Handles Chalice, FastAPI, and Flask differences for deploys, local runs, and stack management.
- **`scripts/aws_big_lambda/big_lambdas_manager.sh`** — Main SAM orchestrator (79KB). Manages the full Docker-based Lambda build/deploy lifecycle.
- **`scripts/local_db/run_local_db_docker.sh`** + **`local_db_stack.yml`** — Unified Docker Compose management for all local databases.
- **`scripts/run_app_tests.sh`** — Sets up the full test environment including MongoDB container startup and `.env` backup/restore.

### How Consumer Projects Use These Scripts

Consumer projects install via NPM and invoke through `node_modules/genericsuite-be-scripts/scripts/`. Their `Makefile` delegates everything to this package. Environment is configured through `.env` files per stage (dev, qa, staging, prod).

### Deployment Flow (SAM/Big Lambda)

1. `config_*` targets generate `.chalice/config.json` from environment templates
2. `deploy_*` targets call `big_lambdas_manager.sh sam_deploy <stage>` which:
   - Builds a Docker image (AL2 -Amazon Linux- or Alpine variant)
   - Runs SAM build/package/deploy
   - Uses stage-specific S3 buckets (created by `create_s3_bucket_*` targets)

### Database Engine Values

Current canonical values (renamed in v1.3.0):
- `MONGODB` (was `MONGO_DB`)
- `DYNAMODB` (was `DYNAMO_DB`)
- `POSTGRESQL`
- `MYSQL`
- `SUPABASE`

Directory rename history: `mongo/` → `local_db/`, `postgres/` → `sql_db/`

## Code Style Guidelines

- Follow the code style guidelines in @docs/codeStyle.md

## Publishing

Security scanning (`sast-test`) is **mandatory** before publishing. The `make publish` script enforces this and prompts for manual confirmation before pushing to npm. Use `UPDATE_SNAPSHOTS=1` to regenerate test snapshots when publishing after snapshot changes.

## Important Notes

- The `AGENTS.md` file (if present) is a symlink to `CLAUDE.md` — edit only `CLAUDE.md`.
- Skills, commands, rules, and sub-agents are located in the `.claude/` directory.
- Scripts detect Docker vs Podman via `scripts/container_engine_manager.sh`.
- Node version is pinned to 20 via `.nvmrc`.
- Default Python package manager is `uv`; scripts also support `poetry` and `pipenv`.
- Generated files (`.chalice/config.json`, `docker-compose.yml`, `Dockerfile`, `samconfig.toml`) are git-ignored — they are produced by config/build targets.
