# frozen_string_literal: true

RSpec.describe "Rails PSQL JSONB Querying" do
  before(:all) do
    Friend.create!(name: "Chill Friend", props: { "chill" => true, "age" => 20, "nested": { "inside": 1 } })
    Friend.create!(name: "Ageless Friend", props: { "ping" => "pong" })
    Friend.create!(name: "Old Friend", props: { "age" => 90, "nested": { "inside": 1 } })
    Friend.create!(name: "Dog Friend", props: { "dog_name" => "Milo", "age" => 25, "nested": { "inside": 2 } })
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
    above_20 =  Friend.jsonb_where(column_name: "props", json_keys: ["age"], operator: "gt", value: 20)
    expect(above_20.length).to eq(2)
  end

  it "can query with exclusion" do
    # Note the subtle differences between specifying key and not

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

  it "can order by jsonb field" do
    q = Friend.all.jsonb_order(column_name: "props", json_keys: ["age"], direction: "desc")

    # NULL values are sorted first for desc and last for asc
    expect(q.map(&:name)).to eq(["Ageless Friend", "Old Friend", "Dog Friend", "Chill Friend"])
  end
end
