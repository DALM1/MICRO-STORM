FROM ruby:3.2

RUN apt-get update && apt-get install -y \
    build-essential autoconf automake libtool pkg-config \
    libssl-dev zlib1g-dev libprotobuf-dev protobuf-compiler

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN gem update --system
RUN gem install bundler -v "~>2.4"
# RUN bundle install --jobs=1 --retry=3 --no-document

COPY . /app

EXPOSE 3630
EXPOSE 4567
EXPOSE 50051

CMD ["/bin/bash", "-c", "ruby auth_app.rb & ruby server_grpc.rb"]
