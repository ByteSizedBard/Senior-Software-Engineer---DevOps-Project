# Almanac — Terraform + Database Reliability

Built by ByteSizedBard.

Stack: Terraform, AWS, Docker Compose, PostgreSQL, GitHub Actions, Shell scripting.

This repo covers two independent halves of the assessment (project codename: **Almanac** —
the hotel-booking domain and reliability focus made "keeping a good record" feel apt):

1. **Terraform** — AWS infrastructure design (`Internet → ALB → ECS/Fargate → RDS`), for
   two environments (`dev`, `prod`), with a CI workflow that runs `fmt` / `init` /
   `validate` / `plan` on every PR (no real AWS deployment required).
2. **Database** — a local PostgreSQL instance (Docker Compose) with a migrated schema,
   an optimized query index, 200 rows of seed data, and backup/restore scripts.

## Repository structure

```
infra/
  modules/
    network/    # VPC, public+private subnets, IGW, NAT, ALB/ECS/RDS security groups
    ecs/        # ALB, target group/listener, ECS cluster, Fargate task+service
    rds/        # RDS instance (private, in the private subnets)
  envs/
    dev/        # smaller instance, 1-day backup retention, deletion protection OFF
    prod/       # larger instance, 30-day backup retention, deletion protection ON
db/
  migrations/
    001_create_tables.sql   # hotel_bookings + booking_events
    002_add_indexes.sql     # the query-optimization index
  seed/
    seed.sql                # 200 bookings across 5 cities / 5 orgs / 4 statuses + events
scripts/
  backup.sh                 # timestamped pg_dump from the running compose container
  restore.sh                # restores a dump into a brand-new database + verifies it
docker-compose.yml           # local Postgres, auto-runs migrations + seed on first start
.github/workflows/terraform.yml   # fmt/init/validate/plan on PRs, for both dev and prod
```

## Part 1–3: Terraform

### Design

```
Internet → ALB (public subnets) → ECS/Fargate service (private subnets) → RDS (private subnets)
```

- The VPC has public subnets (ALB only) and private subnets (ECS tasks + RDS). A single NAT
  gateway lets ECS tasks reach the internet (e.g. to pull container images) without being
  publicly reachable themselves. This is a deliberate cost/simplicity trade-off for an
  assessment: one NAT gateway is a single point of failure across AZs. A production setup
  would run one NAT gateway per AZ instead.
- Security groups are chained: `alb-sg` accepts port 80 from the internet; `ecs-sg` accepts
  the container port **only from `alb-sg`**; `rds-sg` accepts the DB port **only from
  `ecs-sg`**. RDS has `publicly_accessible = false` and sits only in private subnets. There's
  no HTTPS listener in this assessment's ECS module, so there's no 443 ingress rule either —
  adding one would mean provisioning an ACM certificate too, which felt like unnecessary
  scope for a plan-only exercise.
- `infra/modules/*` are reusable; `infra/envs/{dev,prod}` each instantiate them with their
  own `tfvars`, backend state file, and sizing — this is the "two environments" structure
  the assessment asks for.
- Availability zones and the AWS region are passed in as **plain variables** rather than
  looked up via `aws_availability_zones` / `aws_region` data sources. Those data sources
  make real AWS API calls even during `terraform plan`; passing them as variables means
  `plan` doesn't depend on reaching a real AWS account at all.

### dev vs prod

| Setting | dev | prod |
|---|---|---|
| `db_instance_class` | `db.t3.micro` | `db.r6g.large` |
| `db_allocated_storage` | 20 GB | 100 GB |
| `db_backup_retention_period` | 1 day | 30 days |
| `db_deletion_protection` | `false` | `true` |
| `db_skip_final_snapshot` | `true` (disposable) | `false` (always snapshot on destroy) |
| `db_multi_az` | `false` | `true` |
| `desired_count` (ECS tasks) | 1 | 2 |
| Backend state file (local, for this assessment) | `terraform.dev.tfstate` | `terraform.prod.tfstate` |

State is local for both environments in this repo, so `terraform init` works standalone
with no pre-created AWS backend resources. Each env's `backend.tf` documents, in a comment,
the equivalent S3 + DynamoDB backend a real deployment would use instead.

### Running it locally

Set placeholder AWS credentials first. This is plan-only — no real AWS account is ever
touched — but the AWS provider still wants *some* credential source present even with
`skip_credentials_validation` / `skip_requesting_account_id` / `skip_metadata_api_check`
set in `providers.tf`; those flags stop it from validating or looking anything up, they
don't substitute for having a value there at all.

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

(PowerShell: `$env:AWS_ACCESS_KEY_ID="test"`, `$env:AWS_SECRET_ACCESS_KEY="test"`,
`$env:AWS_DEFAULT_REGION="us-east-1"`.)

```bash
cd infra/envs/dev

terraform fmt -check -recursive ../..
terraform init
terraform validate
terraform plan -refresh=false -var-file="dev.tfvars"
```

Repeat in `infra/envs/prod` with `prod.tfvars`. `db_password` has a plan-only placeholder
default (`assessment-plan-only-password`), so this runs unattended with no prompt; override
it with `-var`, `TF_VAR_db_password`, or a secrets manager for anything beyond a plan-only
check — never commit a real one.

`terraform init` generates `.terraform.lock.hcl` in each env directory; commit those
(they're intentionally not in `.gitignore`) so CI and anyone else resolve the exact same
provider version/checksums. **This zip does not include them** — generating one requires
network access to the provider registry, which this repo's build environment didn't have.
`fmt` was checked for real with a Terraform-compatible binary and the module wiring was
confirmed structurally valid; `init`/`validate`/`plan` still need to be run for real, either
here or via the CI workflow, before submitting.

### CI (`.github/workflows/terraform.yml`)

Runs on every pull request touching `infra/**`, as a matrix over `dev` and `prod`:
`terraform fmt -check` → `init` → `validate` → `plan -refresh=false`. The plan is posted
as a PR comment (inside a collapsible `<details>` block) and uploaded as a workflow
artifact. Since the backend is local, `init` needs no AWS credentials or pre-created state
resources; the AWS *provider* still normally tries to validate credentials and look up the
account ID even for `plan`, so each env's `providers.tf` sets `skip_credentials_validation`,
`skip_requesting_account_id`, and `skip_metadata_api_check` — that's what actually lets
`plan` run with the placeholder `AWS_ACCESS_KEY_ID=test` in the workflow, not the
placeholder credentials by themselves. Combined with `-refresh=false` and the
plain-variable AZs/region noted above, nothing in the plan depends on real AWS
infrastructure existing. GitHub Actions runners have normal internet access, so the
provider plugin download that fails in this repo's sandboxed build environment will
succeed there.

## Part 4–6: Database

### Run it

```bash
docker compose up -d
docker compose ps          # wait for "healthy"
```

On first start (empty data volume), Postgres automatically runs, in order:
`001_create_tables.sql` → `002_add_indexes.sql` → `seed.sql` (mounted as `003_seed_data.sql`).
Postgres only executes **top-level files** in `/docker-entrypoint-initdb.d`, not
subdirectories, which is why `docker-compose.yml` mounts each SQL file individually rather
than mounting the `db/migrations/` and `db/seed/` folders wholesale.

Connect directly if you want to poke around:

```bash
docker exec -it almanac_db psql -U app_admin -d almanac
```

### Schema (`db/migrations/001_create_tables.sql`)

`hotel_bookings` and `booking_events` as specified in the assessment, plus two sanity
constraints (`checkout_date > checkin_date`, `amount >= 0`) and a foreign key from
`booking_events.booking_id` to `hotel_bookings.id`.

### Seed data (`db/seed/seed.sql`)

200 bookings generated via `generate_series`, spread across 5 cities, 5 organizations, and
4 statuses, with `created_at` spread over the last 90 days (so some rows fall inside and
some outside the target query's 30-day window). `booking_events` rows are added for a
subset of bookings (a `created` event for ~40%, plus a `status_changed` event for ~20%).
The script is idempotent — it `TRUNCATE`s both tables first, so it's safe to re-run.

One implementation note worth calling out: the first draft picked each row's city/org/status
with `(SELECT city FROM cities ORDER BY random() LIMIT 1)`. That looks like it varies per
row, but because the subquery doesn't reference anything in the outer row, Postgres
evaluates it once and reuses the same result for all 200 rows — every booking ended up with
the same city. The fix was to pick a random array index (`(ARRAY[...])[1 + floor(random() *
n)]`) directly in the row's own expression list, which Postgres has to evaluate per row.
This was caught by actually running the seed against a live Postgres instance and checking
`COUNT(DISTINCT city)`, rather than just reading the SQL.

### Query optimization (`db/migrations/002_add_indexes.sql`)

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added:

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

- `city` and `created_at` are the key columns because they're what the `WHERE` clause
  filters on — `city` first because it's the equality predicate, `created_at` second
  because it's the range predicate. (Not claiming `city` is more selective in general —
  that depends on the real data distribution.)
- `org_id`, `status`, `amount` are added via `INCLUDE` rather than as extra key columns.
  They're not used for filtering or ordering, but including them makes it *possible* for
  Postgres to satisfy the whole query — filter *and* `GROUP BY`/`COUNT`/`SUM` — straight
  from the index, without touching the table (an index-only scan). `INCLUDE` doesn't
  guarantee that plan gets chosen, though: the planner also weighs table statistics, cost
  estimates, and the visibility map, and recently-modified rows can still force a heap
  fetch. Use `EXPLAIN ANALYZE` on your own data to confirm which plan it actually picks.
- On the 200-row seed data in this repo, `EXPLAIN ANALYZE` does show
  `Index Only Scan using idx_hotel_bookings_city_created_at` rather than a sequential scan
  — but that's this dataset's size and distribution, not a guarantee for every dataset.

### Backup and restore

```bash
./scripts/backup.sh                              # writes ./backups/almanac_<timestamp>.dump
./scripts/restore.sh                              # restores the most recent backup
./scripts/restore.sh backups/almanac_20260101_0000.dump   # or a specific file
```

- `backup.sh` runs `pg_dump -Fc` (Postgres's compressed custom format) inside the running
  `almanac_db` container and writes a timestamped file under `./backups/`.
- `restore.sh` does **not** restore over the live `almanac` database. It drops and recreates
  a separate `almanac_restore_test` database inside the same container, restores the dump
  into that fresh database with `pg_restore --no-owner --no-privileges`, and then verifies
  the restore actually worked by checking, inside `almanac_restore_test`:
  - `hotel_bookings` row count > 0
  - `booking_events` row count > 0
  - the `idx_hotel_bookings_city_created_at` index exists
  
  It prints all three counts and exits non-zero if any check fails, so "did the restore
  actually work" isn't just a visual check — the script fails loudly if it didn't.
- Both scripts were dry-run against a real local PostgreSQL 16 install before being
  committed: backup → drop → fresh create → restore → verify, end to end, to make sure the
  exact command sequence (not just the shell syntax) is correct.

## Submission checklist

- [x] Terraform infrastructure code (`infra/modules/`)
- [x] `dev` and `prod` Terraform environment examples (`infra/envs/`)
- [x] Docker Compose database setup (`docker-compose.yml`)
- [x] SQL migration files (`db/migrations/`)
- [x] Seed data script (`db/seed/seed.sql`)
- [x] Database backup script (`scripts/backup.sh`)
- [x] Database restore script (`scripts/restore.sh`)
- [x] README with setup and verification steps (this file)
- [x] (Optional) GitHub Actions Terraform workflow (`.github/workflows/terraform.yml`)
