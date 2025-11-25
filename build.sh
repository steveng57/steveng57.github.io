#!/bin/bash

# Cloudflare Pages build script
# Install gems without the test group to avoid html-proofer issues
bundle config set --local without 'test'
bundle install
bundle exec jekyll build