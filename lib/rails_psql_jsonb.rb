# frozen_string_literal: true

require "active_support/concern"
require "active_record"
require "active_record/connection_adapters/postgresql_adapter"

require_relative "rails_psql_jsonb/version"
require_relative "rails_psql_jsonb/errors"
require_relative "rails_psql_jsonb/query_helpers"
require_relative "rails_psql_jsonb/querying"
require_relative "rails_psql_jsonb/atomic_update"

module RailsPsqlJsonb
  extend ActiveSupport::Concern
  include RailsPsqlJsonb::Querying
  include RailsPsqlJsonb::AtomicUpdate
end
