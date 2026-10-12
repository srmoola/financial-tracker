require "rails_helper"

RSpec.describe "Confirming an email address", type: :request do
  include ActiveJob::TestHelper

  def sign_up
    perform_enqueued_jobs do
      post sign_up_path, params: { user: { first_name: "Ada", last_name: "Lovelace", email_address: "ada@example.com", password: "password123", password_confirmation: "password123" } }
    end
    ActionMailer::Base.deliveries.last
  end

  def code_from(mail) = mail.subject[/\d{6}/]

  before { ActionMailer::Base.deliveries.clear }

  it "emails a 6-digit code at sign-up and keeps the app locked until it's entered" do
    mail = sign_up

    expect(mail.to).to eq([ "ada@example.com" ])
    expect(mail.subject).to match(/\A\d{6} is your Financial Tracker code\z/)
    expect(mail.text_part.body.to_s).to include(code_from(mail), "expires in 15 minutes")

    get root_path
    expect(response).to redirect_to(email_verification_path)
    get transactions_path
    expect(response).to redirect_to(email_verification_path)

    get email_verification_path
    expect(response.body).to include("Check your email", "ada@example.com", 'autocomplete="one-time-code"')
  end

  it "confirms the email with the right code, accepting spaces or a dash" do
    code = code_from(sign_up)

    post email_verification_path, params: { code: "#{code[0, 3]} #{code[3, 3]}" }

    expect(response).to redirect_to(onboarding_path)
    expect(User.find_by!(email_address: "ada@example.com")).to be_email_verified
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "rejects a wrong code, and locks the code after 5 wrong tries" do
    code = code_from(sign_up)
    wrong = code == "000000" ? "111111" : "000000"

    post email_verification_path, params: { code: wrong }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("That code isn&#39;t right")

    4.times { post email_verification_path, params: { code: wrong } }
    expect(response.body).to include("Too many wrong codes")

    post email_verification_path, params: { code: }
    expect(response.body).to include("Too many wrong codes")
    expect(User.find_by!(email_address: "ada@example.com")).not_to be_email_verified
  end

  it "rejects an expired code" do
    code = code_from(sign_up)

    travel 16.minutes do
      post email_verification_path, params: { code: }
    end

    expect(response.body).to include("That code has expired")
  end

  it "sends a new code on request, at most once a minute" do
    old_code = code_from(sign_up)

    perform_enqueued_jobs { post resend_email_verification_path }
    expect(flash[:alert]).to include("Wait a minute")

    travel 61.seconds do
      perform_enqueued_jobs { post resend_email_verification_path }
      expect(flash[:notice]).to include("We sent a new code")
      new_code = code_from(ActionMailer::Base.deliveries.last)

      post email_verification_path, params: { code: old_code } unless old_code == new_code
      expect(response).to have_http_status(:unprocessable_content) unless old_code == new_code
      post email_verification_path, params: { code: new_code }
      expect(response).to redirect_to(onboarding_path)
    end
  end

  it "lets an unconfirmed user log out" do
    sign_up

    delete session_path

    expect(response).to redirect_to(new_session_path)
  end

  it "sends confirmed users away from the code page" do
    code = code_from(sign_up)
    post email_verification_path, params: { code: }

    get email_verification_path

    expect(response).to redirect_to(root_path)
  end

  it "stores only a digest of the code" do
    code = code_from(sign_up)

    expect(User.find_by!(email_address: "ada@example.com").email_verification_code_digest).not_to include(code)
  end
end
