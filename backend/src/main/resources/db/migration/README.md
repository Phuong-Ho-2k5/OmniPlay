# Database migrations

Migrations execute in this order:

| Version | Responsibility |
| --- | --- |
| V1 | Create the four PostgreSQL enums |
| V2–V24 | Create one table per file (23 tables, 130 columns); retain PK/UNIQUE/CHECK with each table |
| V25 | Add all 34 foreign keys after every table exists |
| V26 | Create all 25 additional indexes |
| V27 | Seed reference genres, Quest templates and Badges |
| V28, opt-in `db/demo` location | Seed demo accounts, media, Posts, saved content and playlist |

PK/UNIQUE constraints create their own indexes automatically; V26 contains the
additional indexes from the design. Foreign keys retain their approved delete rules.
The dedicated column, constraint, index and foreign-key workbook tabs in
`docs/Database/` define the physical schema, with the updated XP rule below.

`V27__seed_reference_data.sql` installs four genres, Q01–Q10, and the three Badges.
The optional `../demo/V28__seed_demo.sql` adds demo accounts, media, Posts, saved
content and a playlist with an item at five Skip. Enable it with the `demo` profile;
ordinary startup only loads V1–V27. Demo file generation is separate from Flyway.

The user's updated reward rule overrides the original documents' fixed 10 XP:
`xp_reward = target_count * (source_scope == SAVED ? 15 : 10)`. Both templates and
daily Quest snapshots enforce it. Seed rewards are Q01=10, Q02=10, Q03=15, Q04=15,
Q05=30, Q06=15, Q07=10, Q08=20, Q09=20, Q10=30. Badge thresholds stay 10/50/100.

Use an empty dedicated database for the first setup. These migrations do not adopt
an old experimental database with a different Flyway history, including the former
combined V1/V2/V3 layout. Use a fresh development/demo database for this split layout.
Do not enable
`baseline-on-migrate`, run `repair`, or edit checksums to conceal a different schema.
Switching off the demo profile after V28 has run does not delete its data.

Hibernate uses `ddl-auto: validate`; schema changes must be made through migrations.
Do not edit a migration after it has been applied to a shared database. Add a new one.

See the [backend README](../../../../../README.md) for local database and media setup.
