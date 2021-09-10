FROM ruby:2.6

# Prereqs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
&& apt-get update -q \
&& apt-get install -y nodejs yarn

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
