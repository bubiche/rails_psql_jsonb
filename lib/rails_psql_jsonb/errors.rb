# frozen_string_literal: true

module RailsPsqlJsonb
  module Errors
    class InvalidColumnName < StandardError
      def initialize(table_name:, column_name:)
        super("Table #{table_name} does not have jsonb column name #{column_name}")
      end
    end

    class InvalidOperator < StandardError
      def initialize(value:)
        super("Invalid operator #{value}")
      end
    end

    class InvalidOrder < StandardError
      def initialize(value:)
        super("only `asc` or `desc` can be used for ordering, got: #{value}")
      end
    end

    class ReadOnlyAttribute < StandardError
      def initialize(attribute:)
        super("#{attribute} is marked as readonly")
      end
    end

    class NoOrderKey < StandardError
      def initialize(attribute:)
        super("order json keys should not be empty")
      end
    end

    class ActiveRecordError < StandardError
    end
  end
end