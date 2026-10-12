namespace :plaid do
  desc "After re-linking a bank (e.g. for more history), move balance history, category edits and notes from the older connection to the newer one and remove the older one. Usage: bin/rails \"plaid:replace_connection[you@example.com,Capital One]\""
  task :replace_connection, %i[ email institution ] => :environment do |_task, args|
    user = User.find_by!(email_address: args.fetch(:email).to_s.strip.downcase)
    items = user.plaid_items.where(institution_name: args.fetch(:institution)).order(:created_at).to_a
    abort "Expected 2 connections to #{args[:institution]} for #{user.email_address}, found #{items.size}." unless items.size == 2

    old_item, new_item = items
    puts "Replacing the #{old_item.created_at.to_date} connection with the #{new_item.created_at.to_date} one..."
    result = PlaidConnectionReplacement.new(old_item, new_item).run!

    puts "Matched #{result.accounts_matched} account(s), moved #{result.snapshots_moved} balance snapshot(s), copied #{result.edits_copied} transaction(s) with category edits or notes."
    puts "Couldn't find #{result.edits_unmatched} edited transaction(s) in the new connection; their edits were removed with the old one." if result.edits_unmatched.positive?
    puts "Not matched (their data was removed with the old connection): #{result.unmatched_accounts.join(", ")}" if result.unmatched_accounts.any?
    puts "Removed the old connection."
  end
end
