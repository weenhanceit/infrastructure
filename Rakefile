# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/*_test.rb"]
end

desc "Run tests"
task default: :test

require "bundler/gem_tasks"
require "chandler/tasks"

# Add chandler as a prerequisite for `rake release`
task "release:rubygem_push": "chandler:push"
