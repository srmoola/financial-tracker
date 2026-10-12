Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :sign_up, only: %i[ show create ]
  resource :onboarding, only: :show, controller: "onboarding"

  # Connecting accounts with Plaid Link
  resources :accounts, only: :index
  # Whether the daily sync ran for each recent day
  resource :sync_history, only: :show, path: "accounts/sync-history"
  resources :plaid_link_tokens, only: :create, path: "plaid/link_tokens"
  resources :plaid_items, only: %i[ create destroy ] do
    post :statement_dates, on: :member
  end

  # App sections that aren't built yet. Each gets a placeholder page until its real controller exists.
  resources :transactions, only: %i[ index update ]

  %w[ budgets subscriptions taxes ].each do |section|
    get section, to: "coming_soon#show", defaults: { section: section }, as: section
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Solid Queue dashboard (Mission Control - Jobs)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Sent emails in development (letter_opener_web)
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end
