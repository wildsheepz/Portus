FROM opensuse/leap:15.3

ENV COMPOSE=1
EXPOSE 3000

WORKDIR /srv/Portus
COPY Gemfile* ./

# Let's explain this RUN command:
#   1. First of all we add d:l:go repo to get the latest go version.
#   2. Then refresh, since opensuse/ruby does zypper clean -a in the end.
#   3. Then we install dev. dependencies and the devel_basis pattern (used for
#      building stuff like nokogiri). With that we can run bundle install.
#   4. We then proceed to remove unneeded clutter: first we remove some packages
#      installed with the devel_basis pattern, and finally we zypper clean -a.
COPY Guardfile .
COPY Rakefile .
COPY VERSION .
COPY app app
COPY bin bin
COPY config config
COPY config.ru .
COPY db db
COPY lib lib
COPY package.json .
COPY public public
COPY yarn.lock .
COPY .ruby-version .
COPY vendor/assets vendor/assets
RUN zypper addrepo https://download.opensuse.org/repositories/devel:/tools/openSUSE_Leap_15.3/ devel:tools && \
    zypper --gpg-auto-import-keys ref && \
    zypper -n in --no-recommends \
           libmariadb-devel postgresql-devel \
           nodejs libxml2-devel libxslt1 git-core \
           go1.10 phantomjs gcc-c++ curl bzip2 postgresql-server-devel shared-mime-info npm8 && \
    zypper -n in --no-recommends -t pattern devel_basis && \
       git clone -b v1.1.2 https://github.com/rbenv/rbenv.git ~/.rbenv && \
       (cd ~/.rbenv && src/configure && make -C src) && \
       echo 'PATH="$HOME/.rbenv/bin:$PATH"' >> /etc/bash.bashrc && \
       export PATH="$HOME/.rbenv/bin:$PATH" && \
       echo $PATH && \
       echo 'eval "$(rbenv init -)"' >> /etc/bash.bashrc && \
       eval "$(rbenv init -)" && \
       mkdir -p "$(rbenv root)"/plugins && \
       git clone -b v20210804 https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build &&\
       rbenv install 2.6.8 && \
       rbenv shell 2.6.8 && \
       update-alternatives --install /usr/bin/bundle bundle `rbenv which bundle` 3 && \
       update-alternatives --install /usr/bin/bundler bundler `rbenv which bundler` 3 && \
       export GEM_PATH=/srv/Portus/vendor/bundle/ruby/2.6.0 GEM_HOME=/srv/Portus/vendor/bundle/ruby/2.6.0  && \
       bundle update mimemagic && \
       bundle install --retry=3 && \
       # gem install rails &&\
       # gem install psych -v '3.1.0' --source 'https://rubygems.org/' && \
       # gem install json -v '2.1.0' --source 'https://rubygems.org/' && \
    go get -u github.com/vbatts/git-validation && \
    go get -u github.com/openSUSE/portusctl && \
    mv /root/go/bin/git-validation /usr/local/bin/ && \
    mv /root/go/bin/portusctl /usr/local/bin/ && \
           npm install; \
           PORTUS_SECRET_KEY_BASE="ap" PORTUS_KEY_PATH="ap" PORTUS_PASSWORD="ap"   INCLUDE_ASSETS_GROUP=yes RAILS_ENV=production NODE_ENV=production bundle exec rake portus:assets:compile ;\
    zypper -n rm wicked wicked-service autoconf automake \
           binutils bison cpp flex gdbm-devel gettext-tools \
           libtool m4 make makeinfo curl bzip2 libpython2_7-1_0 nodejs8 npm8 python-base python-rpm-macros && \
           rm -rf \
              vendor/cache \
              node_modules \
              public/assets/application-*.js* \
              vendor/assets \
              examples \
              packaging \
              tmp \
              log \
              docker \
              doc \
              *.orig && \
              find . -name "spec" -type d -exec rm -rfv {} + ; \
              find vendor/bundle -name "test" -type d ! -path "*rack*/test" -exec rm -rfv {} + ; \
              find . -name ".github" -type d -exec rm -rfv {} + ; \
              find . -name ".empty_directory" -type d -delete ; \
              find . -size 0 ! -path "*gem.build_complete" -delete ; \
    zypper clean -a

RUN ln /root/.rbenv/versions/2.6.8/bin/ruby /usr/bin/ruby.ruby2.6.8 && \
       ln -sf ruby.ruby2.6.8 /usr/bin/ruby && \
       ln /root/.rbenv/versions/2.6.8/bin/gem /usr/bin/gem && \
       ln /root/.rbenv/versions/2.6.8/lib/libruby.so.2.6.8 /lib64/libruby.so.2.6.8 && \
       ln -sf libruby.so.2.6.8 /lib64/libruby.so.2.6 && \
       ln -sf libruby.so.2.6.8 /lib64/libruby.so && \
       ln -sf /usr/bin/bundler /srv/Portus/vendor/bundle/ruby/2.6.0/bin/bundler.ruby2.6 && \
       ln -sf /usr/bin/bundle /srv/Portus/vendor/bundle/ruby/2.6.0/bin/bundle.ruby2.6
COPY docker/init /
RUN chmod +x /init && \
       rm -rf /etc/pki/trust/anchors && \
       ln -sf /certificates /etc/pki/trust/anchors
ENTRYPOINT ["/init"]