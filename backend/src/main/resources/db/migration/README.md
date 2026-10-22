# Database migrations

Add versioned Flyway SQL migrations here when the first database tables are introduced,
for example `V1__create_initial_tables.sql`. There is no application schema yet.

Hibernate uses `ddl-auto: validate`; schema changes must be made through migrations.
Do not edit a migration after it has been applied to a shared database. Add a new one.
