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


    # can add field
    first_key = "first_key_test"
    first_value = "first_value_test"
    instance.jsonb_update!({ JSONB_FIELD => { first_key => first_value } })
    expect(instance[JSONB_FIELD][first_key]).to eq(first_value)

    # can add another field without overwriting
    second_key = "second_key"
    second_value = "second_value"
    instance.jsonb_update!({ JSONB_FIELD => { second_key => second_value } })
    expect(instance[JSONB_FIELD][second_key]).to eq(second_value)
    expect(instance[JSONB_FIELD][first_key]).to eq(first_value)

    # can update field
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

    # can set int
    int_value = 1
    instance.jsonb_update!({ JSONB_FIELD => { test_key => int_value } })
    expect(instance[JSONB_FIELD][test_key]).to eq(int_value)

    # can set string
    string_value = "string"
    instance.jsonb_update!({ JSONB_FIELD => { test_key => string_value } })
    expect(instance[JSONB_FIELD][test_key]).to eq(string_value)

    # can set array
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
end
