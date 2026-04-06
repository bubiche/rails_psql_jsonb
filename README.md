# RailsPsqlJsonb

Helpers for querying and atomically updating PostgreSQL JSONB columns in Rails ActiveRecord.

Inspired by https://github.com/madeintandem/jsonb_accessor and https://github.com/antoinemacia/atomic_json

## Installation

Add to your Gemfile:

```ruby
gem "rails_psql_jsonb"
```

Include in your model:

```ruby
class Friend < ApplicationRecord
  include RailsPsqlJsonb
end
```

## Usage

### Querying

**Contains / equality / numeric comparison**

```ruby
# @> contains
Friend.jsonb_where(column_name: "props", operator: "contains", value: { age: 90 })

# Numeric operators: gt, lt, gte, lte, eq  (also accept >, <, >=, <=, =)
Friend.jsonb_where(column_name: "props", json_keys: ["age"], operator: "gt", value: 20)

# Nested key path
Friend.jsonb_where(column_name: "props", json_keys: ["address", "city"], operator: "eq", value: "Berlin")

# Exclusion
Friend.jsonb_where_not(column_name: "props", operator: "contains", value: { active: true })
```

**Key existence**

```ruby
# Records where the key exists
Friend.jsonb_where_exists(column_name: "props", key: "age")

# Records where the key is absent
Friend.jsonb_where_exists(column_name: "props", key: "age", exclude: true)

# Records having any of the given keys
Friend.jsonb_where_exists_any(column_name: "props", keys: ["age", "score"])

# Records having all of the given keys
Friend.jsonb_where_exists_all(column_name: "props", keys: ["age", "name"])

# Scope check to a nested object
Friend.jsonb_where_exists(column_name: "props", key: "city", json_keys: ["address"])
```

**Ordering**

```ruby
Friend.all.jsonb_order(column_name: "props", json_keys: ["age"], direction: "desc")
# NULLs sort first for desc, last for asc
```

### Updating

All update methods are atomic at the database level using `jsonb_set`.

**Set / merge keys**

```ruby
# Merges new keys without overwriting unrelated keys
friend.jsonb_update!({ "props" => { "age" => 31 } })
friend.jsonb_update!({ "props" => { "age" => 31, "score" => 100 } })

# Without touching updated_at
friend.jsonb_update_columns({ "props" => { "age" => 31 } })

# Without running validations
friend.jsonb_update({ "props" => { "age" => 31 } })
```

**Delete a key**

```ruby
friend.jsonb_delete_key("props", "age")                    # removes props['age']
friend.jsonb_delete_key("props", "address", "city")        # removes props['address']['city']
friend.jsonb_delete_key_columns("props", "age")            # no updated_at touch
```

**Array operations**

```ruby
# Append — initializes to [value] if the key doesn't exist
friend.jsonb_array_append("props", ["tags"], "ruby")

# Remove all occurrences — returns [] if the last element is removed
friend.jsonb_array_remove("props", ["tags"], "ruby")
```

**Numeric increment / decrement**

```ruby
friend.jsonb_increment("props", ["score"])        # +1 (default)
friend.jsonb_increment("props", ["score"], 5)     # +5
friend.jsonb_increment("props", ["score"], -1)    # -1 (decrement)
# Missing key is initialized to 0 before applying the delta
```

**Batch update**

```ruby
# Wraps multiple jsonb_update! calls in a single transaction
Friend.jsonb_batch_update([
  [friend_a, { "props" => { "score" => 10 } }],
  [friend_b, { "props" => { "score" => 20 } }],
])
```

### GIN index recommendation

For best query performance, create a GIN index on your JSONB column. Use `jsonb_gin_index_sql` to get the correct SQL for your migration:

```ruby
# In a migration:
execute Friend.jsonb_gin_index_sql(column_name: "props")
# => CREATE INDEX ON "friends" USING GIN ("props" jsonb_path_ops);

# jsonb_path_ops  — smaller index, faster for @> (contains) queries (default)
# jsonb_ops       — also supports ?, ?|, ?& key-existence operators
execute Friend.jsonb_gin_index_sql(column_name: "props", using: :jsonb_ops)
```

## Development

To run tests you must have [PostgreSQL](https://www.postgresql.org/) installed and create the test database:

```sh
PGPASSWORD=postgres createdb -U postgres -h localhost rails_psql_jsonb_test
```

Tests assume PostgreSQL is running on `localhost:5432` with username `postgres` and password `postgres`.

After checking out the repo, run `bin/setup` to install dependencies. Then run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To release a new version, update `version.rb`, then run `bundle exec rake release` to create a git tag, push commits and the tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
