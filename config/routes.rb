Rails.application.routes.draw do
  get 'welcome/index'
  resources :job_posts do
    resources :job_applications
  end

  root to: 'welcome#index'
end
