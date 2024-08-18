# frozen_string_literal: true

require "rails_psql_jsonb"
require "logger"
require "active_record"

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "rails_psql_jsonb_test",
  host: "127.0.0.1",
  port: 5432,
  username: "postgres",
  password: "postgres"
)

ActiveRecord::Schema.define do
  drop_table :friends, if_exists: true
  drop_table :mutate_test_friends, if_exists: true

  create_table :friends do |t|
    t.text :name
    t.jsonb :props, default: {}
  end

  create_table :mutate_test_friends do |t|
    t.text :name
    t.jsonb :props, default: {}
  end
end

ActiveRecord::Base.logger = Logger.new($stdout, level: :warn)

class Friend < ActiveRecord::Base
  include RailsPsqlJsonb
  self.table_name = "friends"
end

class MutateTestFriend < ActiveRecord::Base
  include RailsPsqlJsonb
  self.table_name = "mutate_test_friends"
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    # treat warnings as errors
    expect_any_instance_of(Logger).to_not receive(:warn)
  end
end
