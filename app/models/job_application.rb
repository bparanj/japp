class JobApplication < ApplicationRecord
  belongs_to :job_post
  belongs_to :user

  validates :body, presence: true
  has_one_attached :cv
end
