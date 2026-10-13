class CreateAvatars < ActiveRecord::Migration[8.1]
  def change
    # A user's uploaded picture, kept in the database so it survives deploys
    # without file storage. Separate from users so it isn't loaded on every request.
    create_table :avatars, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.binary :image, null: false
      t.timestamps
    end
  end
end
