# frozen_string_literal: true

RSpec.describe "Rails PSQL JSONB Atomic Update" do
  JSONB_FIELD = "props"
  NON_JSONB_FIELD = "name"
  INVALID_FIELD = "invalid_field"

  def create_test_instance
    MutateTestFriend.create!(name: SecureRandom.hex(10))
  end

  it "#update_key can update field" do
    instance = create_test_instance

    first_key = "first_key_test"
    first_value = "first_value_test"
    instance.jsonb_update!({ JSONB_FIELD => { first_key => first_value } })
    expect(instance[JSONB_FIELD][first_key]).to eq(first_value)

    second_key = "second_key"
    second_value = "second_value"
    instance.jsonb_update!({ JSONB_FIELD => { second_key => second_value } })
    expect(instance[JSONB_FIELD][second_key]).to eq(second_value)
    expect(instance[JSONB_FIELD][first_key]).to eq(first_value)

    instance.jsonb_update!({ JSONB_FIELD => { first_key => second_value } })
    expect(instance[JSONB_FIELD][first_key]).to eq(second_value)
  end

  it "#update_key can update multiple fields" do
    instance = create_test_instance

    first_key = "first_key_test"
    first_value = "first_value_test"
    second_key = "second_key"
    second_value = "second_value"

    instance.jsonb_update!(
      { JSONB_FIELD => { first_key => first_value, second_key => second_value } },
    )
    expect(instance[JSONB_FIELD][first_key]).to eq(first_value)
    expect(instance[JSONB_FIELD][second_key]).to eq(second_value)
  end

  it "#update_key updates atomically" do
    instance = create_test_instance

    first_key = "first_key_test"
    second_key = "second_key_test"
    test_value = "test_value"

    threads = []
    threads << Thread.new do
      instance.jsonb_update!({ JSONB_FIELD => { first_key => test_value } })
    end
    threads << Thread.new do
      instance.jsonb_update!({ JSONB_FIELD => { second_key => test_value } })
    end

    threads.each(&:join)

    expect(instance[JSONB_FIELD][first_key]).to eq(test_value)
    expect(instance[JSONB_FIELD][second_key]).to eq(test_value)
  end

  it "#update_key can set different value types" do
    instance = create_test_instance
    test_key = "test_key"

    int_value = 1
    instance.jsonb_update!({ JSONB_FIELD => { test_key => int_value } })
    expect(instance[JSONB_FIELD][test_key]).to eq(int_value)

    string_value = "string"
    instance.jsonb_update!({ JSONB_FIELD => { test_key => string_value } })
    expect(instance[JSONB_FIELD][test_key]).to eq(string_value)

    array_value = [1, 2, 3]
    instance.jsonb_update!({ JSONB_FIELD => { test_key => array_value } })
    expect(instance[JSONB_FIELD][test_key]).to eq(array_value)
  end

  it "#update_key fails for non jsonb field" do
    instance = create_test_instance

    expect do
      instance.jsonb_update!({ NON_JSONB_FIELD => { "test_key" => "test_value" } })
    end.to raise_error(RailsPsqlJsonb::Errors::InvalidColumnName)
  end

  it "#update_key fails for non-existent field" do
    instance = create_test_instance

    expect do
      instance.jsonb_update!({ INVALID_FIELD => { "test_key" => "test_value" } })
    end.to raise_error(RailsPsqlJsonb::Errors::InvalidColumnName)
  end

  it "#update_key fails if new instance" do
    instance = MutateTestFriend.new
    expect do
      instance.jsonb_update!({ JSONB_FIELD => { "test_key" => "test_value" } })
    end.to raise_error(RailsPsqlJsonb::Errors::ActiveRecordError)
  end

  it "#update_key fails if destroyed instance" do
    instance = create_test_instance
    instance.destroy!
    expect do
      instance.jsonb_update!({ JSONB_FIELD => { "test_key" => "test_value" } })
    end.to raise_error(RailsPsqlJsonb::Errors::ActiveRecordError)
  end

  describe "input validation" do
    it "does not mutate the input hash" do
      instance = create_test_instance
      input = { JSONB_FIELD => { "key" => "value" } }
      original_id = input.object_id
      original_inner_id = input[JSONB_FIELD].object_id

      instance.jsonb_update!(input)

      expect(input.object_id).to eq(original_id)
      expect(input[JSONB_FIELD].object_id).to eq(original_inner_id)
      expect(input[JSONB_FIELD]["key"]).to eq("value")
    end

    it "raises ArgumentError for an empty column payload" do
      instance = create_test_instance
      expect do
        instance.jsonb_update!({ JSONB_FIELD => {} })
      end.to raise_error(ArgumentError, /must not be empty/)
    end
  end

  describe "value types" do
    it "stores nil as JSON null" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "key" => nil } })
      expect(instance[JSONB_FIELD]["key"]).to be_nil
    end

    it "stores boolean values correctly" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "flag" => true } })
      expect(instance[JSONB_FIELD]["flag"]).to eq(true)

      instance.jsonb_update!({ JSONB_FIELD => { "flag" => false } })
      expect(instance[JSONB_FIELD]["flag"]).to eq(false)
    end

    it "handles deeply nested updates" do
      # Pre-create structure via AR; jsonb_set requires parent paths to exist
      instance = MutateTestFriend.create!(name: SecureRandom.hex(10), props: { "a" => { "b" => { "c" => { "d" => 0 } } } })
      instance.jsonb_update!({ JSONB_FIELD => { "a" => { "b" => { "c" => { "d" => 99 } } } } })
      expect(instance[JSONB_FIELD]["a"]["b"]["c"]["d"]).to eq(99)
    end
  end

  describe "timestamps" do
    it "touches updated_at on jsonb_update!" do
      instance = create_test_instance
      original_updated_at = instance.updated_at
      sleep(0.01)
      instance.jsonb_update!({ JSONB_FIELD => { "key" => "value" } })
      expect(instance.updated_at).to be > original_updated_at
    end

    it "does not touch updated_at on jsonb_update_columns" do
      instance = create_test_instance
      original_updated_at = instance.updated_at
      sleep(0.01)
      instance.jsonb_update_columns({ JSONB_FIELD => { "key" => "value" } })
      instance.reload
      expect(instance.updated_at.to_f).to be_within(0.001).of(original_updated_at.to_f)
    end
  end

  describe "jsonb_delete_key" do
    it "deletes a top-level key" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "age" => 30, "name" => "Alice" } })
      instance.jsonb_delete_key(JSONB_FIELD, "age")
      expect(instance[JSONB_FIELD].key?("age")).to eq(false)
      expect(instance[JSONB_FIELD]["name"]).to eq("Alice")
    end

    it "deletes a nested key without affecting siblings" do
      # Pre-create structure via AR; jsonb_set can't build multi-key objects into empty paths
      instance = MutateTestFriend.create!(name: SecureRandom.hex(10), props: { "nested" => { "a" => 1, "b" => 2 } })
      instance.jsonb_delete_key(JSONB_FIELD, "nested", "a")
      expect(instance[JSONB_FIELD]["nested"].key?("a")).to eq(false)
      expect(instance[JSONB_FIELD]["nested"]["b"]).to eq(2)
    end

    it "no-ops gracefully when the key does not exist" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "existing" => "value" } })
      expect { instance.jsonb_delete_key(JSONB_FIELD, "nonexistent") }.not_to raise_error
      expect(instance[JSONB_FIELD]["existing"]).to eq("value")
    end

    it "raises ArgumentError when key_path is empty" do
      instance = create_test_instance
      expect do
        instance.jsonb_delete_key(JSONB_FIELD)
      end.to raise_error(ArgumentError, /must not be empty/)
    end
  end

  describe "jsonb_array_append" do
    it "appends a value to an existing array" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "tags" => ["ruby"] } })
      instance.jsonb_array_append(JSONB_FIELD, ["tags"], "rails")
      expect(instance[JSONB_FIELD]["tags"]).to eq(["ruby", "rails"])
    end

    it "creates [value] when the key does not exist" do
      instance = create_test_instance
      instance.jsonb_array_append(JSONB_FIELD, ["tags"], "ruby")
      expect(instance[JSONB_FIELD]["tags"]).to eq(["ruby"])
    end

    it "appends atomically from concurrent threads" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "tags" => [] } })

      threads = []
      threads << Thread.new { MutateTestFriend.find(instance.id).jsonb_array_append(JSONB_FIELD, ["tags"], "ruby") }
      threads << Thread.new { MutateTestFriend.find(instance.id).jsonb_array_append(JSONB_FIELD, ["tags"], "rails") }
      threads.each(&:join)

      instance.reload
      expect(instance[JSONB_FIELD]["tags"]).to contain_exactly("ruby", "rails")
    end
  end

  describe "jsonb_array_remove" do
    it "removes a matching value from the array" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "tags" => ["ruby", "rails", "ruby"] } })
      instance.jsonb_array_remove(JSONB_FIELD, ["tags"], "ruby")
      expect(instance[JSONB_FIELD]["tags"]).to eq(["rails"])
    end

    it "no-ops when the value is not in the array" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "tags" => ["ruby"] } })
      instance.jsonb_array_remove(JSONB_FIELD, ["tags"], "python")
      expect(instance[JSONB_FIELD]["tags"]).to eq(["ruby"])
    end

    it "returns [] when the last element is removed" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "tags" => ["ruby"] } })
      instance.jsonb_array_remove(JSONB_FIELD, ["tags"], "ruby")
      expect(instance[JSONB_FIELD]["tags"]).to eq([])
    end
  end

  describe "jsonb_increment" do
    it "increments by 1 by default" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "score" => 5 } })
      instance.jsonb_increment(JSONB_FIELD, ["score"])
      expect(instance[JSONB_FIELD]["score"]).to eq(6)
    end

    it "decrements with a negative delta" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "score" => 10 } })
      instance.jsonb_increment(JSONB_FIELD, ["score"], -3)
      expect(instance[JSONB_FIELD]["score"]).to eq(7)
    end

    it "increments by a float delta" do
      instance = create_test_instance
      instance.jsonb_update!({ JSONB_FIELD => { "score" => 1.5 } })
      instance.jsonb_increment(JSONB_FIELD, ["score"], 0.5)
      expect(instance[JSONB_FIELD]["score"]).to eq(2.0)
    end

    it "initializes a missing key to 0 before incrementing" do
      instance = create_test_instance
      instance.jsonb_increment(JSONB_FIELD, ["score"], 5)
      expect(instance[JSONB_FIELD]["score"]).to eq(5)
    end

    it "raises TypeError when delta is not Numeric" do
      instance = create_test_instance
      expect do
        instance.jsonb_increment(JSONB_FIELD, ["score"], "one")
      end.to raise_error(TypeError, /delta must be Numeric/)
    end
  end
end
