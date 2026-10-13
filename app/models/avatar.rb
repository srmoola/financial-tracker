require "image_processing/vips"

# A user's uploaded picture, resized to a square WebP (without the photo's
# metadata, like where it was taken) and kept in the database, so it survives
# deploys without file storage.
class Avatar < ApplicationRecord
  SIZE = 256
  MAX_UPLOAD_SIZE = 10.megabytes
  CONTENT_TYPE = "image/webp"

  belongs_to :user

  validate :image_from_upload

  # Resizes the uploaded file into `image`; anything that isn't an image (or is too big) leaves it empty.
  def upload=(file)
    self.image = (resize(file) if file.respond_to?(:path) && file.size <= MAX_UPLOAD_SIZE)
  end

  private
    def resize(file)
      ImageProcessing::Vips.source(file.path).resize_to_fill(SIZE, SIZE).convert("webp").saver(strip: true).call.then do |resized|
        File.binread(resized.path).tap { resized.close! }
      end
    rescue Vips::Error
      nil
    end

    def image_from_upload
      errors.add(:base, "Pick a photo (JPEG, PNG, WebP or GIF) under #{MAX_UPLOAD_SIZE / 1.megabyte} MB") if image.blank?
    end
end
