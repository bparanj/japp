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

## Issues

1. Provide a way to create a new Rails app without providing all the steps in the command line and installing anything on the host.

2. bin/yarn install and bin/rails assets:precompile are not cached by buildx. How to fix this problem?