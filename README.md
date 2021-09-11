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

```
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

Run the migrations:

```
docker-compose run --rm web bin/rails db:migrate
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

```
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


## Issues

1. Provide a way to create a new Rails app without providing all the steps in the command line and installing anything on the host.

2. bin/yarn install and bin/rails assets:precompile are not cached by buildx. How to fix this problem?

3. How to tail the development log file? 