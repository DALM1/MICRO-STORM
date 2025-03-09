FROM ruby:3.2

WORKDIR /app
COPY . /app
RUN gem install bundler
RUN bundle install
RUN mkdir -p /app/public/uploads
RUN chmod 755 /app/public/uploads
EXPOSE 3630
EXPOSE 4567

CMD ["/bin/bash", "-c", "ruby auth_app.rb & ruby server.rb"]
