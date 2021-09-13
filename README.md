## Create the Rails App

```
docker run -it --rm -v ${PWD}:/usr/src -w /usr/src ruby:2.6 sh -c 'curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
&& apt update -y \
&& apt install -y yarn nodejs \
&& gem install rails:"~> 6.0" \
&& rails new --skip-listen --database=postgresql japp'
```

## Build the Image

```
docker build -t japp:latest .
```

## Create a Model

```
docker run --rm -it -v ${PWD}:/usr/src/app japp:latest bin/rails g scaffold JobPost title body:text
```

## Create Database Container

```
docker run -it -d --env POSTGRES_USER=rails --env POSTGRES_PASSWORD=secret123 --env POSTGRES_DB=japp_development --name my_db postgres:11
```

## Connect to Database

Run the server:

```
docker run -it -d --env POSTGRES_USER=rails --env POSTGRES_PASSWORD=secret123 --env POSTGRES_DB=japp_development --name my_db2 postgres:11
```

Run the client:

```
docker run --rm -it --link my_db2:db postgres:11 psql -h db --user=rails --pass japp_development
```

## Configure Database

In database.yml:

```yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch('POSTGRES_USER') { 'postgres' } %>
  password: <%= ENV.fetch('POSTGRES_PASSWORD') { '' } %>
  host: <%= ENV.fetch('POSTGRES_HOST') { 'db' } %>
  
development:
  <<: *default
  database: japp_development

test:
  <<: *default
  database: japp_test

production:
  <<: *default
  database: japp_production
  username: japp
  password: <%= ENV['JAPP_DATABASE_PASSWORD'] %>
```

## Connect Rails to Database Container

```
docker run -d -it --link my_db2:db --mount src=$PWD,dst=/usr/src,type=bind --env POSTGRES_HOST=db --env POSTGRES_USER=rails --env POSTGRES_PASSWORD=secret123 --publish 3000:3000 --name my_app japp:latest
```

Rails container is not running. Not able to load localhost:3000. 

Change the exec form to shell form in Dockerfile:

```
CMD rails s -b 0.0.0.0 -p $PORT
```

Rebuild the image.

```
docker build -t japp:latest .
```

## Run the Rails App

```
docker run --rm -it -p 3000:3000 -v ${PWD}:/usr/src/app japp
```

## Stop and Remove the Database Container

```
docker stop 6fc1f4716be6
```

```
docker container rm my_db2
```

## Create a New Volume and Mount PostgreSQL Container

```
 docker run -d -it --mount type=volume,source=my_db_data,target=/var/lib/postgresql/data/pgdata --env POSTGRES_USER=rails --env POSTGRES_PASSWORD=secret123 --env POSTGRES_DB=japp_development --env PGDATA=/var/lib/postgresql/data/pgdata --name my_db2 postgres:11
```

Check the database logs to verify it is running:

```
docker logs my_db2
```

## Run Database Migration

Create the database:

```
docker run --rm -it --link my_db2:db --mount src=$PWD,dst=/usr/src/app,type=bind --env POSTGRES_HOST=db --env POSTGRES_USER=rails --env POSTGRES_PASSWORD=secret123 japp:latest bin/rails db:create
```

Run migration:

```
docker run --rm -it --link my_db2:db --mount src=$PWD,dst=/usr/src/app,type=bind --env POSTGRES_HOST=db --env POSTGRES_USER=rails --env POSTGRES_PASSWORD=secret123 japp:latest bin/rails db:migrate
```

Create some job posts using the UI.

## Create a Docker Compose File

```
version: '3.9'

services: 
  db:
    image: postgres:11
    environment: 
      - PGDATA=/var/lib/postgresql/data/pgdata
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=secret123
    volumes: 
      - dbdata:/var/lib/postgresql/data/pgdata
  
  web:
    build: .
    ports: 
      - '3000:3000'
    environment: 
      - RAILS_ENV=development
      - RACK_ENV=development
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=secret123
    volumes: 
      - .:/usr/src/app
    depends_on: 
      - db

volumes: 
  dbdata:
    driver: local
```

Shut down and remove previous containers:

```
docker rm -f my_db my_app
```

## Build Images using Docker Compose

```
docker-compose build
```

Using buildkit with docker-compose: https://www.docker.com/blog/faster-builds-in-compose-thanks-to-buildkit-support/

## Migrate Database using Docker Compose

```
docker-compose run --rm web rails db:create db:migrate
```

Verify:

```
docker-compose up -d web
japp_db_1 is up-to-date
Creating japp_web_1 ... 
Creating japp_web_1 ... error

ERROR: for japp_web_1  Cannot start service web: driver failed programming external connectivity on endpoint japp_web_1 (4ea47c2c1cef96e25b4db14c23e17e35f5cda49eb58e8574dd93839bb9e10982): Bind for 0.0.0.0:3000 failed: port is already allocated

ERROR: for web  Cannot start service web: driver failed programming external connectivity on endpoint japp_web_1 (4ea47c2c1cef96e25b4db14c23e17e35f5cda49eb58e8574dd93839bb9e10982): Bind for 0.0.0.0:3000 failed: port is already allocated
ERROR: Encountered errors while bringing up the project.
```

Find the Rails server running on 3000 and stop it.

```
docker container ls
```

```
docker container stop 35bd10e9a808
```

## Persisting Data

```
docker-compose up -d web
```

shows no records. To see the records created previously, change the docker-compose.yml volumes section:

```
volumes: 
  dbdata:
    external:
      name: my_db_data
```

Stop the container and run:

```
docker-compose up -d web
```

Removing pid:

```
sudo rm server.pid
```

To work within the container:

```
docker run --rm -it japp_web /bin/bash
```

The home page will now show the data that was persisted in my_db_data volume.

## Stopping and Starting Containers

Stop the containers:

```
docker-compose stop
```

Start the containers:

```
docker-compose start
```

Stop and remove containers:

```
docker-compose down
```

Removing individual containers:

```
docker-compose stop web
```

```
docker-compose rm web
```

Recreate application stack:

```
docker-compose up web
```

## Entrypoint

Using the shell form:

```
CMD rails s -b 0.0.0.0 -p $PORT
```

in the Dockerfile does not forward the signal, server.pid file gets left behind.

Create docker-entrypoint.sh:

```
#!/bin/sh

rm -f tmp/pids/server*.pid
bin/rails server -b 0.0.0.0 -p $PORT --pid tmp/pids/server.`hostname`.pid
```

Make it executable:

```
chmod u+x docker-entrypoint.sh
```

Replace the CMD instruction in Dockerfile with:

```
CMD ["./docker-entrypoint.sh"]
```

Rebuild the images:

```
docker-compose build
```

Run the app:

```
docker-compose up web
```

## Add Gem

Add clearance gem to Gemfile. Run:

```
docker run --rm -it -v ${PWD}:/app -w /app ruby:2.6 /bin/sh -c 'bundle lock'
```

## Rebuild Docker Image

```
docker-compose build web
```

This automatically uses buildx plugin if it is installed. Refer the Cache Installed Gems section for instructions.

## Generate Models

```
docker-compose run --rm web bin/rails g clearance:install
```

Configure clearance gem in development.rb:

```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

Change the body section of the layout:

```html
  <body>
   <% if signed_in? %>
     Signed in as: <%= current_user.email %>
     <%= button_to 'Sign out', sign_out_path, method: :delete %>
   <% else %>
     <%= link_to 'Sign in', sign_in_path %>
   <% end %>
   <div id="flash">
      <% flash.each do |key, value| %>
      <div class="flash <%= key %>"><%= value %></div>
      <% end %>
   </div>
   
   <%= yield %>
  </body>
```

Add columns for admin in user model:

```
docker-compose run --rm web bin/rails g migration add_name_and_admin_to_users first_name last_name admin:boolean:index 
```

Create JobApplication model:

```
docker-compose run --rm web bin/rails g scaffold JobApplication body:text job_post:references user:references
```

or

```
docker-compose exec web bin/rails ...
```

Run the migrations:

```
docker-compose run --rm web bin/rails db:migrate
```

or

```
docker-compose exec web bin/rails db:migrate
```

Configure associations and validations:

```ruby
class JobPost < ApplicationRecord
  has_many :job_applications
  has_many :applicants, through: :job_applications

  validates :title, presence: true
  validates :body, presence: true
end
```

THE NEWLY CREATED MODEL FILES IS OWNED BY ROOT. NEED TO FIGURE OUT HOW TO MAKE THE DEV USER THE OWNER WHEN GENERATING NEW FILES.

TEMPORARY WORKAROUND: sudo chown $USER:$USER -R .

Add associations to user model:

```ruby
class User < ApplicationRecord
  include Clearance::User

  has_many :job_posts
  has_many :job_applications, dependent: :destroy
end
```

Add validation to job_application model:

```ruby
class JobApplication < ApplicationRecord
  belongs_to :job_post
  belongs_to :user

  validates :body, presence: true
end
```

## Reset the Database

Run:

```
docker-compose run --rm web bin/rails db:drop db:setup
```

or:

```
docker-compose run --rm web bin/rails db:reset
```

## Run the Rails App

```
docker-compose up web
```

## Setup Authorization

In JobPostsController add:

```ruby
  before_action :require_login, except: [:index, :show]
  before_action :require_admin, except: [:index, :show]
```

In application_controller, add require_admin method:

```ruby
  protected

  def require_admin
    return if current_user.admin?

    flash['notice'] = 'You are not authorized to view this page'
    redirect_to sign_in_url
  end
```

## Create Seed Data

Update seeds.rb:

```ruby
admin = User.where(email: 'admin@example.com').first_or_create! do |u|
  u.first_name = 'Admin'
  u.last_name = 'User'
  u.admin = true
  u.password = 'secret123'
end

# Create some example job posts
job1 = JobPost.where(title: 'Barista').first_or_create! do |post|
  post.body = "We're looking for a barista to join our team!"
end

job2 = JobPost.where(title: 'Office Manager').first_or_create! do |post|
  post.body = 'Manage our office'
end

job3 = JobPost.where(title: 'Marketing Assistant').first_or_create! do |post|
  post.body = 'Help build our marketing strategy'
end

# Create some job applicants
(1..4).each do |n|
  User.where(email: "applicant#{n}@example.com").first_or_create! do |u|
    u.first_name = 'Applicant'
    u.last_name = n.to_s
    u.admin = false
    u.password = 'secret123'
  end
end

# Create some job applications for the posts
JobApplication.where(job_post: job1, user: User.find_by(email: 'applicant1@example.com')) do |jobapp|
  jobapp.body = "Hi! I'm applying for this job."
end

JobApplication.where(job_post: job1, user: User.find_by(email: 'applicant2@example.com')) do |jobapp|
  jobapp.body = "I'd like to apply for this position."
end

JobApplication.where(job_post: job2, user: User.find_by(email: 'applicant3@example.com')) do |jobapp|
 jobapp.body = 'Consider me for this job.'
end

JobApplication.where(job_post: job2, user: User.find_by(email: 'applicant4@example.com')) do |jobapp|
 jobapp.body = 'Please consider my application for this opportunity.'
end
```

## Seed the Database

```
docker-compose run --rm web bin/rails db:seed
```

## Sign in as the Admin

Run the Rails app:

```
docker-compose up web
```

Login as admin.

## Apply Now Feature

Update app/views/job_posts/show.html.erb:

```html
<p>
  <%= link_to "Apply Now", new_job_post_job_application_path(@job_post) %>
</p>
```

Change routes.rb:

```ruby
Rails.application.routes.draw do
  resources :job_posts do
    resources :job_applications
  end

  root to: redirect("/job_posts")
end
```

Update job_applications_controller. See the source code.

Require authentication to apply for a job, update job_applications_controller.rb:

```ruby
  before_action :require_login
  before_action :require_admin, except: [:new, :create]
```

Update job_applications/new.html.erb:

```html
<h1>Apply for <%= @job_post.title %></h1>
<%= render 'form', job_application: @job_application %>
<%= link_to 'Back', job_post_job_applications_path(@job_post) %>
```

Update job_applications/_form.html.erb:

```html
<%= form_with(model: [@job_post, job_application, local: true]) do |form| %>
  <% if job_application.errors.any? %>
    <div id="error_explanation">
      <h2><%= pluralize(job_application.errors.count, "error") %> prohibited this job_application from being saved:</h2>

      <ul>
        <% job_application.errors.each do |error| %>
          <li><%= error.full_message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="field">
    <%= form.label :body %>
    <%= form.text_area :body %>
  </div>

  <div class="actions">
    <%= form.submit %>
  </div>
<% end %>
```

Sign in as a job seeker and apply for a job.

GETTING USER MUST EXIST ERROR: 
    User must exist

This error occurs even if a new user signs up and applies for a job. Update the controller to associate the job application to the current user. See the job_applications_controller.rb.

## Allow Admins to View Job Applications

Update job_posts/index.html.erb. See the code. Update job_applications/index.html.erb. See the code. Login as user and apply for a job. Login as admin and view the job applications: http://localhost:3000/job_posts/3/job_applications 

## Cache Installed Gems

To prevent unncessary bundle install when the Gemfile is not changed. Refer: https://docs.docker.com/buildx/working-with-buildx/

Download buildx from https://github.com/docker/buildx/releases/latest. Create cli-plugins folder in ~/.docker folder and move the downloaded docker buildx to that location. Run:

```
chmod a+x ~/.docker/cli-plugins/docker-buildx
```

From the project root run:

```
docker buildx build .
```

## File Uploads

Add aws-sdk-s3 gem to Gemfile. Run:

```
docker-compose run --rm web bundle lock
```

Build the image:

```
docker-compose build web
```

Configure ActiveStorage:

```
docker-compose run --rm web bin/rails active_storage:install db:migrate
```

Configure config/storage.yml:

```yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id: <%= ENV.fetch('S3_ACCESS_KEY_ID', nil) %>
  secret_access_key: <%= ENV.fetch('S3_SECRET_ACCESS_KEY', nil) %>
  region: <%= ENV.fetch('S3_REGION', 'us-east-1') %> 
  bucket: <%= ENV.fetch('S3_BUCKET', 'your_own_bucket') %>
```

Change production.rb active_storage service to :amazon.

Create attachment assocation in JobApplication:

```ruby
has_one_attached :cv
```

Add file_field to job_applications form:

```html
  <div class="field"> 
    <%= form.label :cv %>
    <%= form.file_field :cv %>
  </div>
```

Update job_applications_controller to permit cv field:

```ruby
    def job_application_params
      params.require(:job_application).permit(:body, :cv)
    end
```

Allow admins to view the uploaded file, update job_applications/show.html.erb:

```html
<% if @job_application.cv.attached? %>
  <p>
    <strong>Attached CV</strong>
    <%= link_to 'Download', rails_blob_path(@job_application.cv, disposition: 'attachment') %>
  </p>
<% end %>
```

Upload a pdf file as a job applicant.

```
docker-compose up -d web
```

Logout and login as admin. View the uploaded file and download it.

## Testing Locally Using Docker

Add factory_bot_rails gem to development and test group in Gemfile.

```ruby
gem 'factory_bot_rails', '~> 5.2.0'
```

Add gem 'minitest-spec-rails', '~> 6.0.2' to test group in Gemfile.

```ruby
gem 'minitest-spec-rails', '~> 6.0.2'
```

Update the Gemfile.lock and rebuild Docker image:

```
docker-compose run --rm web bundle lock
docker-compose build
```

Run the test suite:

```
docker-compose run --rm -e RAILS_ENV=test web bin/rails test
```

Fix the broken tests:

```
rm test/fixtures/*.yml
```

In test_helper.rb, comment out the line:

```
fixtures :all
```

Create factories for the models. In test/factories/users.rb:

```ruby
FactoryBot.define do
  factory :user do
    first_name { 'A' }
    last_name { 'User' }
    email { 'user@example.com' }
    admin { false }
    password { 'secret123' }

    trait :admin do
      first_name { 'An' }last_name { 'Admin' }
      admin { true }
      email { 'admin@example.com' }
    end
  end
end
```

In test/factories/job_posts.rb:

```ruby
FactoryBot.define do
  factory :job_post do
    title { 'A Job Post' }
    body { 'Work for us at our company.' }
  end
end
```

In test/factories/job_applications.rb:

```ruby
FactoryBot.define do
  factory :job_application do
    body { "I'd like to apply for this job" }

    user
    job_post
  end
end
```

In config/environments/test.rb, configure clearance middleware in tests:

```
config.middleware.use Clearance::BackDoor
```

Update the tests. Run the tests:

```
docker-compose run --rm -e RAILS_ENV=test web bin/rails test test/controllers/job_applications_controller_test.rb
```

Run an individual test:

```
docker-compose run --rm -e RAILS_ENV=test web bin/rails test test/controllers/job_applications_controller_test.rb:10
```

Fixing any stale or leftover data:

```
docker-compose run --rm -e RAILS_ENV=test web bin/rails db:drop db:create db:schema:load
```

## Using Gaurd to Run Tests Locally

Add guard to Gemfile in development group:

```
gem 'guard'
gem 'guard-minitest'
```

Regemerate Gemfile.lock:

```
docker-compose run --rm web bundle lock
```

Rebuild the image:

```
docker-compose build
```

Add a guard container to docker-compose.yml:

```
  guard:
    build: .
    environment: 
      - RAILS_ENV=development
      - RACK_ENV=development
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=secret123
    volumes: 
      - .:/usr/src/app
    depends_on: 
      - db
    command: bundle exec guard --no-bundler-warning --no-interactions
```

Initialize the Guard configuration:

```
docker-compose run --rm web guard init minitest
```

Warning: you have a Gemfile, but you're not using bundler or RUBYGEMS_GEMDEPS

Update the Guardfile. Run Guard via Docker:

```
docker-compose run --rm guard
```

Error:

```
/usr/local/bundle/gems/webdrivers-4.6.1/lib/webdrivers/chrome_finder.rb:21:in `location': Failed to find Chrome binary. (Webdrivers::BrowserNotFound)
	from /usr/local/bundle/gems/webdrivers-4.6.1/lib/webdrivers/chrome_finder.rb:10:in `version'

22:32:39 - INFO - Guard is now watching at '/usr/src/app'
```

## Fix ChromeDriver Error

In the test group of the Gemfile, add:

```ruby
  gem 'webdrivers', require: !ENV['SELENIUM_REMOTE_URL']
```

Update the docker-compose.yml:

```yml
version: '3.9'

services: 
  db:
    image: postgres:11
    environment: 
      - PGDATA=/var/lib/postgresql/data/pgdata
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=secret123
    volumes: 
      - dbdata:/var/lib/postgresql/data/pgdata
  
  web:
    build: .
    ports: 
      - '3000:3000'
    environment: 
      - SELENIUM_REMOTE_URL=http://webdriver_chrome:4444/wd/hub
      - RAILS_ENV=development
      - RACK_ENV=development
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=secret123
    volumes: 
      - .:/usr/src/app
    depends_on: 
      - db
      - webdriver_chrome

  webdriver_chrome:
    image: selenium/standalone-chrome

  guard:
    build: .
    environment: 
      - RAILS_ENV=development
      - RACK_ENV=development
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=secret123
    volumes: 
      - .:/usr/src/app
    depends_on: 
      - db
    command: bundle exec guard --no-bundler-warning --no-interactions
  
volumes: 
  dbdata:
    external:
      name: my_db_data
```

Rebuild the Docker image:

```
docker-compose build
```

STILL THE SAME ERROR.

Update the Dockerfile:

```
FROM ruby:2.6

# Prereqs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
&& apt-get update -q \
&& apt-get install -y nodejs yarn

RUN curl https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /chrome.deb \
    && dpkg -i /chrome.deb || apt-get install -yf \
    && rm /chrome.deb
    
ARG CHROMEDRIVER_VERSION=83.0.4103.39

RUN apt-get install -y libgconf2-dev \
    && curl https://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip -o /tmp/chromedriver.zip \
    && unzip /tmp/chromedriver.zip -d /usr/local/bin/ \
    && rm /tmp/chromedriver.zip \
    && chmod +x /usr/local/bin/chromedriver

# Cache gems
WORKDIR /tmp

ADD Gemfile .
ADD Gemfile.lock .

RUN bundle install

# Copy app
WORKDIR /usr/src/app

ADD . /usr/src/app

# Precompile assets
RUN bin/yarn install
RUN bin/rails assets:precompile

# Expose port 3000 to other containers
ENV PORT 3000
EXPOSE $PORT

CMD ["./docker-entrypoint.sh"]
```

Rebuild the image:

```
docker-compose build
```

Check the version:

```
docker-compose run --rm web google-chrome --version
Creating japp_web_run ... done
Google Chrome 93.0.4577.63 
```

```
docker-compose run --rm web chromedriver --version
Creating japp_web_run ... done
ChromeDriver 83.0.4103.39 (ccbf011cb2d2b19b506d844400483861342c20cd-refs/branch-heads/4103@{#416})
```

Update chrome driver version in the Docker file:

```
ARG CHROMEDRIVER_VERSION=93.0.4577.63
```

Run the system test:

```
docker-compose run --rm -e RAILS_ENV=test web bin/rails test
```

View screenshots:

```
sudo apt  install eog
```

```
eog tmp/screenshots/capybara-202109121525182762858822.png
```

or

```
xdg-open tmp/screenshots/capybara-202109121525182762858822.png
```

Run all system tests:

```
docker-compose run --rm -e RAILS_ENV=test web bin/rails test test:system
```

## Tail the Development Log File

```
docker-compose logs -f web
```

The log file is created in log/development.log. 

## Running One-Off Commands

Start a new disposable container and run:

```
docker-compose run --rm web echo 'ran a different command'
```

Use a running container and run the command:

```
docker-compose exec web echo 'ran a different command'
```

## Cleaning Up

Stop containers and remove network and volumes:

```
docker-compose down
```

Remove only the containers:

```
docker-compose rm
```

Remove dangling images:

```
docker image prune
```

Remove unused containers:

```
docker container prune
```

Free up unused resources:

```
docker system prune
```

## Managing Containers

List running containers:

```
docker-compose ps
```

Manage container life cycle:

```
docker-compose start|stop|kill|restart|pause|unpause|rm service-name
```

View the logs:

```
docker-compose logs [-f] service-name
```

Run a one-off command in a new, disposable container:

```
docker-compose run --rm service-name some-command
```

Run a one-off command in a running container:

```
docker-compose exec service-name some-command
```

Rebuild an image:

```
docker-compose build service-name
```

Launch all the services of the application:

```
docker-compose up
```

## Start a Redis Server

```
docker run --name redis-container redis
```

Start Redis server:

```
docker-compose up -d redis
```

View the redis logs:

```
docker-compose logs redis
```

Connect to the Redis server:

```
docker-compose run --rm redis redis-cli -h redis
```

List networks:

```
docker network ls
```

## Connecting Rails app to Redis

Uncomment redis gem in Gemfile:

```ruby
gem 'redis', '~> 4.0'
```

Stop Rails container:

```
docker-compose stop web
```

Rebuild custom Rails image:

```
docker-compose build web
```

Start the new container for the latest Rails image:

```
docker-compose up -d web
```

Create a new controller with index action:

```
docker-compose exec web bin/rails g controller welcome index
```

Update the index action:

```ruby
def index
  redis = Redis.new(host: "redis", port: 6379)
  redis.incr("page hits")

  @page_hits = redis.get("page hits")
end
```

Display the page hits in index:

```html
Page hits : <%= pluralize(@page_hits, 'time') %>
```

Update routes.rb:

```ruby
  root to: 'welcome#index'
```

## Running PSQL Command

Indirect way:

```
docker-compose run db bash
/# psql --host=db --username=rails --dbname=japp_development
```

Direct way:

```
docker-compose run --rm db psql --username rails -h db --dbname=japp_development
```

or

```
docker-compose run --rm db psql -U rails -h db --dbname=japp_development
```

Where is the data stored by the database?

```
docker volume inspect --format '{{ .Mountpoint }}' japp_dbdata
/var/lib/docker/volumes/japp_dbdata/_data
```

## Debugging

Add byebug to set a breakpoint in the code. Start an interactive session:

```
docker-compose run --service-ports web
```

Debug in the interactive terminal session. Remove byebug and start web container:

```
docker-compose up -d web
```

## Caching Gems

In Dockerfile, add:

```
ENV BUNDLE_PATH /gems
```

before bundle install. In docker-compose.yml, define the volume for the gem cache directory:

```
   volumes: 
      - .:/usr/src/app
      - gem_cache:/gems
...
volumes: 
  gem_cache:
```

Rebuild web image:

```
docker-compose build web
```

Create a new web container that uses gem_cache volume:

```
docker-compose up -d web
```

Bundler commmands can be run in the web container:

```
docker-compose exec web bundle install
```

Add pry gem to Gemfile development and test group:

```
  gem 'pry'
```

Install the pry gem:

```
docker-compose exec web bundle install
```



## Issues

1. Provide a way to create a new Rails app without providing all the steps in the command line and installing anything on the host.
2. bin/yarn install and bin/rails assets:precompile are not cached by buildx. How to fix this problem?
3. Setup localstack.
4. Configure Rails to log to stdout