FROM ruby:3.2
WORKDIR /app
COPY . /app
RUN gem install bundler
RUN bundle install
EXPOSE 3630
EXPOSE 4567
CMD ["ruby", "auth_app.rb"]
