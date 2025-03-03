FROM ruby:3.2
RUN apt-get update && apt-get install -y libpq-dev
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler
RUN bundle install --jobs=4 --retry=3
COPY . /app
EXPOSE 3630
EXPOSE 4567
EXPOSE 50051
CMD ["/bin/bash", "-c", "ruby auth_app.rb & ruby server_grpc.rb"]
