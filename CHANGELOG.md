## [Unreleased]

## [0.2.0] - 2026-04-07

### Fixed
- Removed debug `puts` statement left in `jsonb_update!`
- Fixed `jsonb_update!` and `jsonb_update_columns` mutating the caller's input hash
- Fixed `self.name.constantize` in querying class methods (broke on anonymous models)
- Fixed `NoOrderKey` error initializer accepting an unused `attribute:` keyword argument
- Fixed `ReadOnlyAttribute` raise syntax (`ReadOnlyAttribute(...)` → `ReadOnlyAttribute.new(...)`)

### Added
- **Key existence queries**: `jsonb_where_exists`, `jsonb_where_exists_any`, `jsonb_where_exists_all` using PostgreSQL `?`, `?|`, `?&` operators
- **Atomic key deletion**: `jsonb_delete_key` / `jsonb_delete_key!` / `jsonb_delete_key_columns` via PostgreSQL `#-`
- **Atomic array append**: `jsonb_array_append` — initializes missing key to `[]` automatically
- **Atomic array remove**: `jsonb_array_remove` — removes all occurrences of a value
- **Atomic numeric increment**: `jsonb_increment` — initializes missing key to `0` automatically
- **Batch update**: `jsonb_batch_update` — wraps multiple `jsonb_update!` calls in a transaction
- **GIN index helper**: `jsonb_gin_index_sql` — returns the SQL to create an optimal GIN index

### Improved
- Multi-key paths use `#>`/`#>>` path operators instead of chained `->` (more idiomatic, better index usage)
- Numeric comparisons use `->>` text extraction before `::float` cast
- `jsonb_order` now emits explicit `NULLS LAST` (asc) / `NULLS FIRST` (desc)
- Trimmed `quoting.rb` to only the methods actually used; fixed `default_timezone` reference
- Added test isolation via `database_cleaner-active_record`

## [0.1.0] - 2024-06-20

- Initial release
