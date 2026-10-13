require "rails_helper"

RSpec.describe "Avatars", type: :request do
  fixtures :users

  # A real photo, wider than it is tall.
  def photo
    path = Rails.root.join("tmp/avatar-spec.jpg").to_s
    (Vips::Image.black(600, 400) + [ 200, 30, 30 ]).write_to_file(path)
    Rack::Test::UploadedFile.new(path, "image/jpeg")
  end

  it "requires login" do
    get avatar_path

    expect(response).to redirect_to(new_session_path)
  end

  context "when logged in" do
    before { sign_in_as users(:one) }

    it "uploads a photo as a small square, shows it and removes it" do
      patch avatar_path, params: { avatar: photo }
      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to include("Your photo is updated.", "Change photo", "/avatar?v=#{users(:one).reload.avatar_version}")

      get avatar_path
      expect(response.media_type).to eq("image/webp")
      expect(response.headers["Cache-Control"]).to include("private")
      image = Vips::Image.new_from_buffer(response.body, "")
      expect([ image.width, image.height ]).to eq([ 256, 256 ])

      delete avatar_path
      follow_redirect!
      expect(response.body).to include("Your photo is removed.", "Upload a photo")
      expect(Avatar.count).to eq(0)
      get avatar_path
      expect(response).to have_http_status(:not_found)
    end

    it "replaces the photo, keeping one per user" do
      2.times { patch avatar_path, params: { avatar: photo } }

      expect(users(:one).reload.avatar).to be_present
      expect(Avatar.count).to eq(1)
    end

    it "says so when the file isn't a photo" do
      patch avatar_path, params: { avatar: Rack::Test::UploadedFile.new(StringIO.new("not a photo"), "image/png", original_filename: "fake.png") }
      follow_redirect!

      expect(response.body).to include("Pick a photo (JPEG, PNG, WebP or GIF) under 10 MB")
      expect(Avatar.count).to eq(0)
    end

    it "only ever shows your own photo" do
      users(:two).create_avatar!(image: "theirs")

      get avatar_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
