# frozen_string_literal: true

RSpec.describe "Rails PSQL JSONB Querying" do
  before(:each) do
    Friend.create!(name: "Chill Friend", props: { "chill" => true, "age" => 20, "nested" => { "inside" => 1 } })
    Friend.create!(name: "Ageless Friend", props: { "ping" => "pong" })
    Friend.create!(name: "Old Friend", props: { "age" => 90, "nested" => { "inside" => 1 } })
    Friend.create!(name: "Dog Friend", props: { "dog_name" => "Milo", "age" => 25, "nested" => { "inside" => 2 } })
  end

  it "can query for something" do
    old_friend = Friend.jsonb_where(column_name: "props", json_keys: ["age"], operator: "contains", value: 90)
    expect(old_friend.length).to eq(1)
    expect(old_friend[0].name).to eq("Old Friend")

    old_friend_2 = Friend.jsonb_where(column_name: "props", operator: "contains", value: { age: 90 })
    expect(old_friend_2.length).to eq(1)
    expect(old_friend_2[0].name).to eq("Old Friend")

    old_friend_3 = Friend.jsonb_where(column_name: "props", json_keys: ["age"], operator: "eq", value: 90)
    expect(old_friend_3.length).to eq(1)
    expect(old_friend_3[0].name).to eq("Old Friend")

    ping_pong_friend = Friend.jsonb_where(column_name: "props", json_keys: ["ping"], operator: "contains", value: "pong")
    expect(ping_pong_friend.length).to eq(1)
    expect(ping_pong_friend[0].name).to eq("Ageless Friend")
  end

  it "can query nested keys" do
    nested_results = Friend.jsonb_where(column_name: "props", json_keys: ["nested", "inside"], operator: "contains", value: 1)
    expect(nested_results.length).to eq(2)
    nested_results_2 = Friend.jsonb_where(column_name: "props", json_keys: ["nested"], operator: "contains", value: { inside: 1 })
    expect(nested_results_2.length).to eq(2)
  end

  it "can query with numeric operator" do
    above_20 = Friend.jsonb_where(column_name: "props", json_keys: ["age"], operator: "gt", value: 20)
    expect(above_20.length).to eq(2)
  end

  it "can query with exclusion" do
    q = Friend.jsonb_where_not(column_name: "props", operator: "contains", value: { age: 20 })
    expect(q.length).to eq(3)
    expect(q.map(&:name).include?("Chill Friend")).to eq(false)

    q2 = Friend.jsonb_where_not(column_name: "props", json_keys: ["age"], operator: "contains", value: 20)
    # The one without age is also excluded since props -> age is NULL
    expect(q2.length).to eq(2)
    expect(q2.map(&:name).include?("Chill Friend")).to eq(false)

    q3 = Friend.jsonb_where_not(column_name: "props", json_keys: ["age"], operator: "lte", value: 20)
    # The one without age is also excluded since props -> age is NULL
    expect(q3.length).to eq(2)
    expect(q3.map(&:name).include?("Chill Friend")).to eq(false)
  end

  it "can order by jsonb field desc — NULLs first" do
    q = Friend.all.jsonb_order(column_name: "props", json_keys: ["age"], direction: "desc")
    # NULL values are sorted first for desc
    expect(q.map(&:name)).to eq(["Ageless Friend", "Old Friend", "Dog Friend", "Chill Friend"])
  end

  it "can order by jsonb field asc — NULLs last" do
    q = Friend.all.jsonb_order(column_name: "props", json_keys: ["age"], direction: "asc")
    # NULL values are sorted last for asc
    expect(q.map(&:name)).to eq(["Chill Friend", "Dog Friend", "Old Friend", "Ageless Friend"])
  end

  describe "jsonb_where edge cases" do
    it "raises InvalidColumnName for a non-jsonb column" do
      expect do
        Friend.jsonb_where(column_name: "name", operator: "eq", value: "test")
      end.to raise_error(RailsPsqlJsonb::Errors::InvalidColumnName)
    end

    it "raises InvalidOperator for an unknown operator" do
      expect do
        Friend.jsonb_where(column_name: "props", operator: "invalid", value: 1)
      end.to raise_error(RailsPsqlJsonb::Errors::InvalidOperator)
    end

    it "can query deeply nested paths" do
      Friend.create!(name: "Deep Friend", props: { "a" => { "b" => { "c" => 42 } } })
      result = Friend.jsonb_where(column_name: "props", json_keys: ["a", "b", "c"], operator: "eq", value: 42)
      expect(result.length).to eq(1)
      expect(result[0].name).to eq("Deep Friend")
    end

    it "can match array containment in jsonb" do
      Friend.create!(name: "Tagged Friend", props: { "tags" => ["ruby", "rails"] })
      result = Friend.jsonb_where(column_name: "props", operator: "contains", value: { "tags" => ["ruby"] })
      expect(result.length).to eq(1)
      expect(result[0].name).to eq("Tagged Friend")
    end
  end

  describe "key existence operators" do
    it "jsonb_where_exists returns records where the key is present" do
      result = Friend.jsonb_where_exists(column_name: "props", key: "age")
      expect(result.map(&:name)).to contain_exactly("Chill Friend", "Old Friend", "Dog Friend")
    end

    it "jsonb_where_exists with exclude: true returns records where the key is absent" do
      result = Friend.jsonb_where_exists(column_name: "props", key: "age", exclude: true)
      expect(result.map(&:name)).to contain_exactly("Ageless Friend")
    end

    it "jsonb_where_exists returns no results for a missing key" do
      result = Friend.jsonb_where_exists(column_name: "props", key: "missing_key")
      expect(result.length).to eq(0)
    end

    it "jsonb_where_exists_any returns records with any of the given keys" do
      result = Friend.jsonb_where_exists_any(column_name: "props", keys: ["dog_name", "ping"])
      expect(result.map(&:name)).to contain_exactly("Dog Friend", "Ageless Friend")
    end

    it "jsonb_where_exists_all returns records with all of the given keys" do
      result = Friend.jsonb_where_exists_all(column_name: "props", keys: ["age", "nested"])
      expect(result.map(&:name)).to contain_exactly("Chill Friend", "Old Friend", "Dog Friend")
    end

    it "jsonb_where_exists with json_keys scopes key check to a nested object" do
      result = Friend.jsonb_where_exists(column_name: "props", key: "inside", json_keys: ["nested"])
      # Only friends with a 'nested' object that has an 'inside' key
      expect(result.map(&:name)).to contain_exactly("Chill Friend", "Old Friend", "Dog Friend")
    end

    it "raises TypeError when ? operator receives an Array value" do
      expect do
        Friend.jsonb_where(column_name: "props", operator: :exists, value: ["age"])
      end.to raise_error(TypeError)
    end

    it "raises TypeError when ?| operator receives a String value" do
      expect do
        Friend.jsonb_where(column_name: "props", operator: :exists_any, value: "age")
      end.to raise_error(TypeError)
    end
  end

  describe "jsonb_order validations" do
    it "raises InvalidOrder for an invalid direction" do
      expect do
        Friend.all.jsonb_order(column_name: "props", json_keys: ["age"], direction: "sideways")
      end.to raise_error(RailsPsqlJsonb::Errors::InvalidOrder)
    end

    it "raises NoOrderKey when json_keys is empty" do
      expect do
        Friend.all.jsonb_order(column_name: "props", json_keys: [], direction: "asc")
      end.to raise_error(RailsPsqlJsonb::Errors::NoOrderKey)
    end
  end
end
