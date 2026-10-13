class User < ApplicationRecord
  # Emailed codes that confirm a new account's email address.
  EMAIL_CODE_EXPIRES_IN = 15.minutes
  EMAIL_CODE_MAX_ATTEMPTS = 5
  EMAIL_CODE_RESEND_AFTER = 1.minute

  has_secure_password
  generates_token_for :weekly_digest # the unsubscribe link in the Monday email
  has_many :sessions, dependent: :destroy
  has_many :plaid_items, dependent: :destroy
  has_many :accounts, through: :plaid_items
  has_many :balance_snapshots, through: :accounts
  has_many :budgets, dependent: :destroy
  has_many :subscription_marks, dependent: :delete_all
  has_one :avatar, dependent: :delete

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :first_name, :last_name, with: ->(name) { name.squish }

  validates :first_name, :last_name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def initials
    "#{first_name.first}#{last_name.first}".upcase
  end

  # When the avatar last changed (for its URL, so a new one isn't cached), or
  # nil without one. Doesn't load the image.
  def avatar_version
    return @avatar_version if defined?(@avatar_version)

    @avatar_version = Avatar.where(user: self).pick(:updated_at)&.to_i
  end

  def email_verified? = email_verified_at.present?

  # A new 6-digit code for confirming the email address, replacing any earlier
  # one. Only its digest is saved; the code itself is returned for the email.
  def generate_email_verification_code!
    SecureRandom.random_number(1_000_000).to_s.rjust(6, "0").tap do |code|
      update!(email_verification_code_digest: email_code_digest(code), email_verification_code_sent_at: Time.current, email_verification_attempts: 0)
    end
  end

  # Checks a code the user typed: :verified, :incorrect, :expired, or
  # :too_many_attempts (after EMAIL_CODE_MAX_ATTEMPTS wrong tries).
  def verify_email_with(code)
    return :expired if email_verification_code_sent_at.nil? || email_verification_code_sent_at < EMAIL_CODE_EXPIRES_IN.ago
    return :too_many_attempts if email_verification_attempts >= EMAIL_CODE_MAX_ATTEMPTS

    if ActiveSupport::SecurityUtils.secure_compare(email_code_digest(code.to_s.gsub(/\D/, "")), email_verification_code_digest.to_s)
      update!(email_verified_at: Time.current, email_verification_code_digest: nil, email_verification_code_sent_at: nil, email_verification_attempts: 0)
      :verified
    else
      increment!(:email_verification_attempts)
      email_verification_attempts >= EMAIL_CODE_MAX_ATTEMPTS ? :too_many_attempts : :incorrect
    end
  end

  def can_resend_email_verification_code?
    email_verification_code_sent_at.nil? || email_verification_code_sent_at <= EMAIL_CODE_RESEND_AFTER.ago
  end

  private
    def email_code_digest(code)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{id}:#{code}")
    end
end
