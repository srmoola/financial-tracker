require "rails_helper"

RSpec.describe User, type: :model do
  it "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    expect(user.email_address).to eq("downcased@example.com")
  end

  it "squishes whitespace in names" do
    user = User.new(first_name: "  Mary  Ann ", last_name: " Smith ")
    expect(user).to have_attributes(first_name: "Mary Ann", last_name: "Smith")
  end

  it "requires a first and last name" do
    user = User.new(email_address: "new@example.com", password: "password123")

    expect(user).not_to be_valid
    expect(user.errors[:first_name]).to include("can't be blank")
    expect(user.errors[:last_name]).to include("can't be blank")
  end

  it "builds a full name and initials" do
    user = User.new(first_name: "ada", last_name: "Lovelace")

    expect(user.full_name).to eq("ada Lovelace")
    expect(user.initials).to eq("AL")
  end
end
