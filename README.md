# RailsPsqlJsonb

Some helpers to work with PostgreSQL's jsonb field for Ruby on Rails' Active Record.

## Usage

More examples in the `spec` folder

```ruby
# Querying
instance = Friend.jsonb_where(column_name: "props", json_keys: ["age"], operator: "contains", value: 90)[0]

# Updating, only works with single key
instance.jsonb_update!({ "props" => { "age" => 30 } })
```

## Development

To run tests you must have [postgresql](https://www.postgresql.org/) installed and create the test database with `PGPASSWORD=postgres createdb -U postgres -h localhost rails_psql_jsonb_test`. Tests assume that postgres is running on `localhost:5432` and can be accessed by username=postgres + password=postgres.

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
