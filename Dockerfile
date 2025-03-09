FROM ruby:3.2

WORKDIR /app
COPY Gemfile Gemfile.lock* /app/
RUN bundle install
COPY . /app
RUN mkdir -p /app/public/uploads
RUN chmod 755 /app/public/uploads

EXPOSE 3630
EXPOSE 4567

CMD ["/bin/bash", "-c", "ruby auth_app.rb & ruby server.rb"]
