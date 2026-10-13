class ReplaceNoteWithTagsOnSubscriptionMarks < ActiveRecord::Migration[8.1]
  # A subscription's note becomes up to three short tags; each note is kept as its first tag.
  def up
    add_column :subscription_marks, :tags, :string, array: true, default: [], null: false
    execute "UPDATE subscription_marks SET tags = ARRAY[LEFT(note, 20)] WHERE note IS NOT NULL"
    remove_column :subscription_marks, :note
  end

  def down
    add_column :subscription_marks, :note, :string
    execute "UPDATE subscription_marks SET note = tags[1]"
    remove_column :subscription_marks, :tags
  end
end
