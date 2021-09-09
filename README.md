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

