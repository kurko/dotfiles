# Rails App Generator Skill

You are a specialized agent for generating new Ruby on Rails applications with a consistent, production-ready setup based on the user's established patterns.

## Overview

This skill creates a new Rails application with:
- Latest stable Rails version (detected dynamically)
- PostgreSQL database
- RSpec testing framework
- Sidekiq + Redis for background jobs
- Devise authentication with User model
- Tailwind CSS
- lib/ directory for domain logic (namespaced under app name)
- Local vendor/bundle gem installation
- Comprehensive development tooling
- Kamal for deployment
- Makefile for common commands

## Ruby Version Detection

**IMPORTANT**: Do not hardcode Ruby versions. Detect available versions dynamically at runtime.

At the start of execution, run:
```bash
rbenv versions
```

This will show all installed Ruby versions. Recommend the latest 3.x version available on the system.

## Frontend Setup Options

When asked about frontend, these are the available choices:

### Option 1: Hotwire Only (Recommended for most apps)
- Turbo + Stimulus (included with Rails)
- Tailwind CSS
- No React/TypeScript
- **Best for**: Traditional Rails apps, CRUD apps, admin panels

### Option 2: Hotwire + React Islands
- Hotwire/Turbo for most of the app
- React + TypeScript available for complex interactive components
- React components rendered in specific places (charts, real-time UIs, complex forms)
- **Best for**: Mostly traditional Rails with some rich interactive features

### Option 3: Full React within Rails
- React app lives inside Rails (in app/javascript)
- Rails as API + some server-rendered views
- React handles most UI
- **Best for**: SPA-like apps that still need Rails views for some pages

### Option 4: Separate React Frontend
- Rails API only (--api flag)
- Separate React app in different directory
- Complete separation of concerns
- **Best for**: True API backends, mobile apps, separate frontend team

## Step-by-Step Generation Process

### STEP 1: Gather Information

First, detect the system environment:
```bash
pwd  # Get current directory
echo $HOME  # Get user's home directory
[ -d "$HOME/www" ] && echo "~/www exists" || echo "~/www does not exist"
rbenv versions  # Get available Ruby versions
```

Then ask the user:
1. **App name** (e.g., "task_tracker", "analytics_dashboard")
2. **Directory location** (default: ~/www/ if it exists, otherwise current directory)
3. **Ruby version** (show available versions from rbenv and recommend the latest 3.x)
4. **Frontend choice** (present the 4 options above)
5. **Brief app description** (to customize Makefile and README)

### STEP 2: Pre-flight Checks

```bash
# Check for latest stable Rails version
gem search '^rails$' --remote | head -1

# Check if latest Rails is installed locally
gem list rails

# If not installed or outdated, install the latest version:
# gem install rails

# Verify rbenv has the selected Ruby version
rbenv versions | grep [selected_version]
```

**Note**: The skill should detect the latest Rails version dynamically and use that version throughout. Do not hardcode version numbers.

### STEP 3: Generate Rails App

```bash
cd [directory_location]

# Set Ruby version for this shell
rbenv local [selected_version]

# Generate Rails app based on frontend choice:

# For Hotwire only (Option 1):
rails new [app_name] --database=postgresql --css=tailwind --javascript=esbuild

# For Hotwire + React Islands (Option 2):
rails new [app_name] --database=postgresql --css=tailwind --javascript=esbuild

# For Full React (Option 3):
rails new [app_name] --database=postgresql --css=tailwind --javascript=esbuild

# For Separate React/API only (Option 4):
rails new [app_name] --api --database=postgresql

cd [app_name]
```

### STEP 4: Configure Bundler for Local Vendor Installation

**CRITICAL**: This must happen before any bundle install!

```bash
bundle config set --local path 'vendor/bundle'
```

This prevents gem conflicts across different Ruby projects.

### STEP 5: Update Gemfile

Add these gems to the Gemfile:

```ruby
# Use the selected Ruby version
ruby "[selected_version]"

gem "rails", "~> [detected_rails_version]"

# Core production gems
gem "pg", "~> 1.1"
gem "redis", "~> 4.0"
gem "hiredis"
gem "kredis"
gem "sidekiq"
gem "clockwork"
gem "devise"
gem "kamal", require: false

# Asset pipeline (if not API-only)
gem "cssbundling-rails"
gem "jsbundling-rails"
gem "sprockets-rails"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "dotenv-rails"
end

group :development do
  gem "web-console"
  gem "spring"
  gem "spring-commands-rspec"
  gem "better_errors"
  gem "binding_of_caller"
  gem "foreman"
  gem "annotate"
  gem "amazing_print"
  gem "niceql"
  gem "rails_sql_prettifier"
  gem "standardrb", require: false
  gem "brakeman", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
  gem "database_cleaner-active_record"
  gem "webmock"
  gem "launchy"
end
```

Then install:

```bash
bundle install
```

### STEP 6: Initialize RSpec

```bash
rails generate rspec:install
```

Configure `spec/spec_helper.rb`:

```ruby
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "tmp/examples.txt"
  config.disable_monkey_patching!

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
```

Configure `spec/rails_helper.rb` (add after existing code):

```ruby
require 'capybara/rspec'
require 'webmock/rspec'

# Sidekiq testing
require 'sidekiq/testing'
Sidekiq::Testing.fake!

# WebMock - allow local connections
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include Time helpers
  config.include ActiveSupport::Testing::TimeHelpers

  # Database Cleaner
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Capybara
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end
```

Create `spec/support/` directory for test helpers:

```bash
mkdir -p spec/support
touch spec/support/.gitkeep
```

Add to `spec/rails_helper.rb` (after the requires at the top):

```ruby
# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }
```

This allows you to organize test helpers, shared examples, and custom matchers in `spec/support/`.

### STEP 7: Configure Rails Generators

In `config/application.rb`, add inside the `class Application < Rails::Application`:

```ruby
# Eager load lib/ directory for domain logic
config.eager_load_paths << Rails.root.join('lib')

# Configure generators
config.generators do |g|
  g.test_framework :rspec,
    fixtures: false,
    view_specs: false,
    helper_specs: false,
    routing_specs: false,
    controller_specs: false,
    request_specs: true,
    feature_specs: true,
    model_specs: true,
    mailer_specs: true
  g.fixture_replacement :factory_bot, dir: 'spec/factories'
end
```

### STEP 8: Configure Database with ENV Variables

Update `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV["WEB_DB_POOL"] || ENV["RAILS_MAX_THREADS"] || 10 %>
  timeout: 20000
  host: <%= ENV.fetch("POSTGRES_HOST", "localhost") %>
  username: <%= ENV.fetch("POSTGRES_USER", "postgres") %>

development:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB", "[app_name]_development") %>

test:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB", "[app_name]_test") %>

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
```

Create `.env`:

```bash
POSTGRES_USER=postgres
POSTGRES_DB=[app_name]_development
POSTGRES_HOST=localhost
REDIS_URL=redis://localhost:6379
REDIS_DB=/1
REDIS_DB_FOR_SIDEKIQ=/0
```

Create `.env.example` (same content, for team reference):

```bash
cp .env .env.example
```

Add to `.gitignore`:

```
.env
```

### STEP 9: Set Up Redis & Sidekiq

Create `config/initializers/redis.rb`:

```ruby
$redis = Redis.new(url: "#{ENV['REDIS_URL']}#{ENV.fetch('REDIS_DB')}")
```

Create `config/initializers/sidekiq.rb`:

```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: "#{ENV['REDIS_URL']}#{ENV.fetch('REDIS_DB_FOR_SIDEKIQ')}" }
  config.logger = Rails.logger
end

Sidekiq.configure_client do |config|
  config.redis = { url: "#{ENV['REDIS_URL']}#{ENV.fetch('REDIS_DB_FOR_SIDEKIQ')}" }
end
```

Add Sidekiq routes to `config/routes.rb`:

```ruby
require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'

  # ... rest of routes
end
```

### STEP 10: Configure Environment Variables Validation

Create `config/initializers/app_env_vars_and_dotenv.rb`:

```ruby
# Define required environment variables by context
module AppEnvVars
  # Essential vars needed for Rails to boot
  ESSENTIAL = %w[
    REDIS_URL
  ].freeze

  # Additional vars needed for full application functionality
  FULL_CONTEXT = %w[
    POSTGRES_HOST
    POSTGRES_USER
    POSTGRES_DB
    REDIS_DB
    REDIS_DB_FOR_SIDEKIQ
  ].freeze

  def self.validate_essential!
    missing = ESSENTIAL.select { |var| ENV[var].nil? || ENV[var].empty? }
    return if missing.empty?

    raise "Missing essential environment variables: #{missing.join(', ')}"
  end

  def self.validate_full!
    missing = (ESSENTIAL + FULL_CONTEXT).select { |var| ENV[var].nil? || ENV[var].empty? }
    return if missing.empty?

    raise "Missing environment variables: #{missing.join(', ')}"
  end

  def self.missing_vars
    (ESSENTIAL + FULL_CONTEXT).select { |var| ENV[var].nil? || ENV[var].empty? }
  end
end

# Only validate essential vars on boot
# bin/doctor will check full context
AppEnvVars.validate_essential! unless Rails.env.test?
```

This pattern allows:
- **Essential vars**: Must be present for Rails to boot
- **Full context**: Checked by bin/doctor before development
- **Flexibility**: Easy to add new required vars per project

### STEP 11: Install & Configure Devise

```bash
rails generate devise:install
rails generate devise User
```

Update `config/initializers/devise.rb` for Hotwire compatibility:

Find and update these lines:

```ruby
# Around line 270
config.navigational_formats = ['*/*', :html, :turbo_stream]

# Around line 308
config.sign_out_via = [:get, :delete]

# Around line 325
config.responder.error_status = :unprocessable_entity
config.responder.redirect_status = :see_other
```

Also update password stretches for test performance:

```ruby
# Around line 120
config.stretches = Rails.env.test? ? 1 : 12
```

### STEP 12: Create lib/ Domain Directory

```bash
mkdir -p lib/[app_name]
```

Create `lib/[app_name]/.gitkeep` to ensure directory is tracked:

```bash
touch lib/[app_name]/.gitkeep
```

Add auto-reloading for development in `config/environments/development.rb`:

```ruby
# Add inside Rails.application.configure do
config.autoload_paths << Rails.root.join('lib')
config.eager_load_paths << Rails.root.join('lib')
```

### STEP 13: Frontend Setup (Based on User Choice)

#### For Hotwire Only (Option 1):
Nothing additional needed - already configured.

#### For Hotwire + React Islands (Option 2):

```bash
yarn add react react-dom @types/react @types/react-dom
```

Update `package.json` to add TypeScript build:

```json
{
  "scripts": {
    "build": "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets --loader:.js=jsx --loader:.tsx=tsx",
    "build:css": "tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify"
  }
}
```

Create `app/javascript/components/` directory:

```bash
mkdir -p app/javascript/components
```

Create example React component `app/javascript/components/Example.tsx`:

```tsx
import React from 'react';

export const Example: React.FC<{ message: string }> = ({ message }) => {
  return <div className="p-4 bg-blue-100">{message}</div>;
};
```

Add `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true
  },
  "include": ["app/javascript/**/*"],
  "exclude": ["node_modules"]
}
```

#### For Full React (Option 3):

Same as Option 2, but create more comprehensive React structure:

```bash
mkdir -p app/javascript/components
mkdir -p app/javascript/pages
mkdir -p app/javascript/hooks
mkdir -p app/javascript/utils
```

#### For Separate React/API (Option 4):

Skip frontend setup in Rails. Document in README that frontend is separate.

### STEP 14: Create Procfile.dev

Create `Procfile.dev`:

```procfile
web: unset PORT && bin/rails server
sidekiq: bundle exec sidekiq
clock: bundle exec clockwork config/clock.rb
```

For non-API apps, also add:

```procfile
js: yarn build --watch
css: yarn build:css --watch
```

### STEP 15: Create Clockwork Configuration

Create `config/clock.rb`:

```ruby
require 'clockwork'
require './config/boot'
require './config/environment'

module Clockwork
  # Example: Run a job every hour
  # every(1.hour, 'hourly.job') do
  #   HourlyJob.perform_later
  # end

  # Example: Run a job every day at 2am
  # every(1.day, 'daily.cleanup', at: '02:00') do
  #   DailyCleanupJob.perform_later
  # end

  # Add your scheduled jobs here
end
```

This provides:
- **clockwork** integration for cron-like scheduled tasks
- **Example patterns** for common scheduling needs
- **Sidekiq integration** via `perform_later`

### STEP 16: Create Custom bin/ Scripts

Create `bin/setup`:

```bash
#!/usr/bin/env ruby
require 'fileutils'

# path to your application root.
APP_ROOT = File.expand_path('..', __dir__)

def system!(*args)
  system(*args) || abort("\n== Command #{args} failed ==")
end

FileUtils.chdir APP_ROOT do
  # This script is idempotent, so that you can run it at any time and get an expectable outcome.
  # Add necessary setup steps to this file.

  puts '== Installing dependencies =='
  system! 'gem install bundler --conservative'
  system('bundle check') || system!('bundle install --path vendor/bundle')

  puts "\n== Preparing database =="
  system! 'bundle exec rails db:prepare'

  puts "\n== Removing old logs and tempfiles =="
  system! 'bundle exec rails log:clear tmp:clear'

  puts "\n== Running health check =="
  system! 'bin/doctor'

  puts "\n== Setup complete! =="
  puts "Run 'make dev' to start the development server"
end
```

Make executable:

```bash
chmod +x bin/setup
```

Create `bin/reset_db`:

```bash
#!/usr/bin/env ruby
require 'fileutils'

APP_ROOT = File.expand_path('..', __dir__)

def system!(*args)
  system(*args) || abort("\n== Command #{args} failed ==")
end

FileUtils.chdir APP_ROOT do
  puts '== Resetting database =='
  puts 'WARNING: This will destroy all data in the database!'
  print 'Are you sure? (yes/no): '

  response = STDIN.gets.chomp
  unless response.downcase == 'yes'
    puts 'Aborted.'
    exit
  end

  system! 'bundle exec rails db:drop db:create db:migrate db:seed'

  puts "\n== Database reset complete! =="
end
```

Make executable:

```bash
chmod +x bin/reset_db
```

Create `bin/dev`:

```bash
#!/usr/bin/env sh

if ! bundle exec gem list foreman -i --silent; then
  echo "Installing foreman..."
  bundle exec gem install foreman
fi

exec bundle exec foreman start -f Procfile.dev "$@"
```

Make executable:

```bash
chmod +x bin/dev
```

Create `bin/doctor`:

```bash
#!/usr/bin/env ruby
require 'fileutils'

puts "🩺 Running health checks...\n\n"

errors = []
warnings = []

# Check for required files
puts "📁 Checking required files..."
required_files = [
  'config/database.yml',
  'config/master.key',
  '.env'
]

required_files.each do |file|
  if File.exist?(file)
    puts "  ✓ #{file}"
  else
    errors << "Missing: #{file}"
    puts "  ✗ #{file}"
  end
end

# Check Rails can boot
puts "\n🚂 Checking Rails environment..."
begin
  require_relative '../config/environment'
  puts "  ✓ Rails environment loads successfully"
rescue => e
  errors << "Rails failed to load: #{e.message}"
  puts "  ✗ Rails environment failed to load"
  puts "    Error: #{e.message}"
end

# Check for Node.js
puts "\n📦 Checking Node.js..."
if system('which node > /dev/null 2>&1')
  node_version = `node --version`.strip
  puts "  ✓ Node.js #{node_version}"
else
  warnings << "Node.js not found - needed for asset compilation"
  puts "  ⚠ Node.js not found"
end

# Check environment variables using AppEnvVars
puts "\n🔐 Checking environment variables..."
missing_vars = AppEnvVars.missing_vars
if missing_vars.empty?
  puts "  ✓ All required environment variables are set"
else
  missing_vars.each do |var|
    warnings << "Missing ENV var: #{var}"
    puts "  ⚠ #{var} not set"
  end
end

# Check database connection
puts "\n🗄️  Checking database connection..."
begin
  ActiveRecord::Base.connection
  puts "  ✓ Database connected"
rescue => e
  errors << "Database connection failed: #{e.message}"
  puts "  ✗ Database connection failed"
  puts "    Error: #{e.message}"
end

# Check Redis connection
puts "\n📮 Checking Redis connection..."
begin
  $redis.ping
  puts "  ✓ Redis connected"
rescue => e
  errors << "Redis connection failed: #{e.message}"
  puts "  ✗ Redis connection failed"
  puts "    Error: #{e.message}"
end

# Summary
puts "\n" + "="*50
if errors.empty? && warnings.empty?
  puts "✅ All checks passed!"
elsif errors.empty?
  puts "⚠️  #{warnings.size} warning(s):"
  warnings.each { |w| puts "  - #{w}" }
else
  puts "❌ #{errors.size} error(s):"
  errors.each { |e| puts "  - #{e}" }
  puts "\n⚠️  #{warnings.size} warning(s):" if warnings.any?
  warnings.each { |w| puts "  - #{w}" }
  exit 1
end
```

Make executable:

```bash
chmod +x bin/doctor
```

Create `bin/dev-web`:

```bash
#!/usr/bin/env sh

unset PORT && bin/rails server
```

Make executable:

```bash
chmod +x bin/dev-web
```

Create `bin/dev-workers`:

```bash
#!/usr/bin/env sh

bundle exec sidekiq
```

Make executable:

```bash
chmod +x bin/dev-workers
```

### STEP 17: Create Makefile

Create `Makefile` with common commands:

```makefile
.PHONY: help test setup dev console db-reset lint annotate deploy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

test: ## Run all tests
	bundle exec rspec spec

setup: ## Initial project setup (after clone)
	bundle config set --local path 'vendor/bundle'
	bundle install
	yarn install
	cp .env.example .env
	rails db:create db:migrate
	@echo "✅ Setup complete! Update .env with your values, then run 'make dev'"

dev: ## Start development server (full stack)
	bin/dev

dev-web: ## Start web server only
	bin/dev-web

dev-workers: ## Start Sidekiq workers only
	bin/dev-workers

console: ## Open Rails console
	bundle exec rails console

db-reset: ## Reset database (destructive!)
	bundle exec rails db:drop db:create db:migrate db:seed

db-migrate: ## Run pending migrations
	bundle exec rails db:migrate

db-rollback: ## Rollback last migration
	bundle exec rails db:rollback

annotate: ## Annotate models with schema info
	bundle exec annotate --models

lint: ## Run StandardRB linter
	bundle exec standardrb

lint-fix: ## Auto-fix StandardRB issues
	bundle exec standardrb --fix

security: ## Run Brakeman security scanner
	bundle exec brakeman

doctor: ## Run health checks
	bin/doctor

deploy: ## Deploy with Kamal
	bundle exec kamal deploy
```

### STEP 18: Initialize Kamal

```bash
bundle exec kamal init
```

This creates:
- `config/deploy.yml` - Kamal configuration
- `.kamal/` - Kamal working directory

Update `.gitignore` to add:

```
.kamal/secrets
```

### STEP 19: Initialize StandardRB

Create `.standard.yml`:

```yaml
fix: true
parallel: true
format: progress
```

### STEP 20: Prepare Database

```bash
bundle exec rails db:prepare
```

**Note**: `db:prepare` is idempotent - it creates the database if needed, runs pending migrations, and updates the schema. This is better than `db:create` + `db:migrate` which can fail if the database already exists.

### STEP 21: Create Structured Seeds

Create `db/seeds/` directory:

```bash
mkdir -p db/seeds
```

Create `db/seeds/development.rb`:

```ruby
# Development seeds
puts "Seeding development database..."

# Example: Create a test user
unless User.exists?(email: 'test@example.com')
  User.create!(
    email: 'test@example.com',
    password: 'password',
    password_confirmation: 'password'
  )
  puts "  ✓ Created test user (test@example.com / password)"
end

puts "Development seeds complete!"
```

Create `db/seeds/production.rb`:

```ruby
# Production seeds (if any)
# Keep this file minimal - production data should come from migrations or imports
puts "Production seeds complete!"
```

Update `db/seeds.rb`:

```ruby
# Load environment-specific seeds
seeds_file = File.join(Rails.root, 'db', 'seeds', "#{Rails.env}.rb")

if File.exist?(seeds_file)
  puts "Loading #{Rails.env} seeds..."
  require seeds_file
else
  puts "No seeds file found for #{Rails.env} environment"
end
```

This provides:
- **Environment separation**: Different seeds for development vs production
- **Idempotent seeds**: Can be run multiple times safely
- **Test data**: Useful default users/data for development

### STEP 22: Run Annotate

```bash
bundle exec annotate --models
```

This will annotate the User model (and future models) with schema info.

### STEP 23: Generate README.md

Create `README.md`:

```markdown
# [App Name]

[App description from user input]

## Prerequisites

- Ruby [version]
- PostgreSQL 12+
- Redis 4.0+
- Node.js 18+ (for asset compilation)

## Setup

Clone the repository and run:

\```bash
bin/setup
\```

This will:
- Install dependencies
- Create and migrate the database
- Seed development data
- Run health checks

## Development

### Starting the Development Server

To start the full development stack (Rails, Sidekiq, Clockwork, asset watchers):

\```bash
make dev
\```

Or use individual commands:
- `make dev-web` - Rails server only
- `make dev-workers` - Sidekiq only
- `bin/dev` - Same as `make dev`

### Environment Variables

Copy `.env.example` to `.env` and update values:

\```bash
cp .env.example .env
\```

Required variables:
- `POSTGRES_HOST` - Database host (default: localhost)
- `POSTGRES_USER` - Database user
- `REDIS_URL` - Redis connection URL

### Common Commands

See `Makefile` for all available commands:

\```bash
make help
\```

Key commands:
- `make test` - Run test suite
- `make console` - Open Rails console
- `make lint` - Run StandardRB linter
- `make lint-fix` - Auto-fix linting issues
- `make db-reset` - Reset database (⚠️ destructive!)
- `make doctor` - Run health checks

### Database

The project uses structured seeds in `db/seeds/`:
- `development.rb` - Development test data
- `production.rb` - Production data (if any)

To re-seed:

\```bash
bundle exec rails db:seed
\```

### Testing

Run the full test suite:

\```bash
make test
\```

Or use RSpec directly:

\```bash
bundle exec rspec
bundle exec rspec spec/models  # Specific directory
bundle exec rspec spec/models/user_spec.rb  # Specific file
\```

### Background Jobs

Background jobs are processed by Sidekiq. To view the Sidekiq dashboard:

Visit http://localhost:3000/sidekiq when the server is running.

Scheduled jobs are defined in `config/clock.rb` using Clockwork.

### Code Quality

This project uses StandardRB for linting:

\```bash
make lint          # Check for issues
make lint-fix      # Auto-fix issues
\```

Security scanning with Brakeman:

\```bash
make security
\```

## Deployment

This project uses [Kamal](https://kamal-deploy.org/) for deployment.

1. Configure `config/deploy.yml` for your environment
2. Set up secrets in `.kamal/secrets`
3. Deploy:

\```bash
make deploy
\```

## Project Structure

\```
├── app/                  # Rails application code
│   ├── models/          # ActiveRecord models
│   ├── controllers/     # Controllers
│   ├── jobs/            # Background jobs
│   └── views/           # View templates
├── lib/[app_name]/      # Domain logic (business objects)
├── spec/                # Test suite
│   ├── models/
│   ├── requests/
│   ├── features/
│   └── support/         # Test helpers
├── config/              # Configuration
│   ├── clock.rb         # Scheduled jobs (Clockwork)
│   └── initializers/
├── db/
│   ├── migrate/         # Database migrations
│   └── seeds/           # Environment-specific seeds
└── bin/                 # Executable scripts
    ├── setup            # Initial setup
    ├── dev              # Development server
    └── doctor           # Health checks
\```

### Domain Logic in lib/

Business logic lives in `lib/[app_name]/`:

\```ruby
module [AppName]
  module Operations
    class ProcessPayment
      def initialize(order, payment_method)
        @order = order
        @payment_method = payment_method
      end

      def call
        # Business logic here
      end
    end
  end
end
\```

## Contributing

[Add contribution guidelines if applicable]

## License

[Add license information]
```

Replace `[App Name]`, `[App description from user input]`, `[version]`, and `[app_name]` with actual values.

### STEP 24: Initialize Git (if not already)

```bash
git init
git add .
git commit -m "Initial commit: Rails [version] app with PG, RSpec, Devise, Sidekiq, Tailwind

Setup includes:
- PostgreSQL with ENV-based config
- RSpec testing framework with DatabaseCleaner, FactoryBot, WebMock
- Devise authentication with User model
- Sidekiq + Redis for background jobs
- Tailwind CSS + [frontend_choice]
- lib/[app_name] for domain logic
- Local vendor/bundle for gem isolation
- Foreman with Procfile.dev
- Custom bin/ scripts (dev, doctor, dev-web, dev-workers)
- Makefile for common tasks
- Kamal for deployment
- StandardRB for linting
- Brakeman for security scanning"
```

### STEP 25: Run Health Check

```bash
bin/doctor
```

Verify all systems are working correctly.

### STEP 26: Verify Full Stack Starts

```bash
make dev
```

**Important**: Let the full stack start and verify it boots without errors. This starts:
- Rails server (web)
- Sidekiq (background jobs)
- Clockwork (scheduled tasks)
- Asset watchers (js/css if applicable)

Check for:
- No missing gem errors
- No database connection errors
- No Redis connection errors
- All processes start successfully
- Server responds on http://localhost:3000

If there are any errors:
1. Read the error message carefully
2. Check which process is failing (web, sidekiq, clock, js, css)
3. Check if it's a missing gem (run `bundle install`)
4. Check if it's a database issue (run `bin/doctor`)
5. Check if it's a Redis issue (ensure Redis is running)
6. Fix the issue before proceeding

Once verified, stop all processes (Ctrl+C) and proceed.

### STEP 27: Final Output to User

Provide the user with:

1. **Summary of what was created**
2. **Next steps**:
   ```
   Your new Rails app '[app_name]' is ready!

   📍 Location: [full_path]
   🐳 Ruby: [version]
   🚂 Rails: [rails_version]
   🎨 Frontend: [choice]

   Next steps:
   1. cd [app_name]
   2. Review and update .env with your settings
   3. Run 'make doctor' to verify everything works
   4. Run 'make dev' to start the development server
   5. Visit http://localhost:3000

   📚 Common commands (see Makefile):
   - make dev          # Start full development stack
   - make test         # Run tests
   - make console      # Rails console
   - make lint         # Run StandardRB
   - make annotate     # Annotate models
   - make doctor       # Health checks

   Happy coding!
   ```

## Important Notes for Execution

### Variable Substitutions

Throughout the generation, replace these placeholders:
- `[app_name]` - The application name provided by user
- `[directory_location]` - Where to create the app
- `[selected_version]` - The Ruby version chosen
- `[frontend_choice]` - Which frontend option was selected

### Error Handling

If any step fails:
1. Show the error clearly
2. Suggest the fix
3. Ask if you should retry or continue

Common issues:
- **PostgreSQL not running**: Ask user to start it
- **Redis not running**: Ask user to start it
- **Port 3000 in use**: Mention in final output that they can use PORT=3001
- **Gem conflicts**: The vendor/bundle setup should prevent this, but suggest `bundle clean` if issues arise

### Testing the Setup

Before marking complete, verify:
- [ ] Rails server starts without errors
- [ ] `bin/doctor` passes all checks
- [ ] `make test` runs (even if no tests yet)
- [ ] User model exists in database
- [ ] lib/[app_name] directory exists and is in load path

## Customization Per App

While most of the setup is standard, ask about:
- **App description** (for README and comments)
- **Initial models needed** (beyond User)
- **Any OAuth providers** (GitHub, Google, etc. - can add OmniAuth gems)
- **Specific gems** the user knows they'll need

## Examples of Domain Logic in lib/

To help the user understand the lib/ structure, explain:

```
lib/
└── [app_name]/
    ├── operations/          # Business operations/services
    │   └── process_payment.rb
    ├── queries/             # Complex queries
    │   └── revenue_report.rb
    ├── validators/          # Custom validators
    │   └── email_format.rb
    └── transformers/        # Data transformations
        └── csv_importer.rb
```

Example class in `lib/[app_name]/operations/process_payment.rb`:

```ruby
module [AppName]
  module Operations
    class ProcessPayment
      def initialize(order, payment_method)
        @order = order
        @payment_method = payment_method
      end

      def call
        # Business logic here
      end

      private

      attr_reader :order, :payment_method
    end
  end
end
```

## Post-Generation Recommendations

Suggest to the user:
1. **Set up GitHub repository** if they want
2. **Configure Kamal** for their hosting (deploy.yml)
3. **Add seeds** for development data
4. **Configure Tailwind** theme (colors, fonts) in tailwind.config.js
5. **Set up CI/CD** (GitHub Actions example available)
6. **Configure production secrets** (Rails credentials)

## Skill Maintenance

This skill was created in November 2025 and is designed to be system-agnostic.

**Key principles:**
1. Always detect Rails version dynamically using `gem search '^rails$' --remote`
2. Always detect available Ruby versions using `rbenv versions`
3. Never hardcode version numbers or system paths
4. Adapt to the current system's configuration

**To update this skill:**
1. Review gem compatibility if Rails has major version changes
2. Update configuration templates if Rails conventions change
3. Check for breaking changes in major gem updates

---

## EXECUTION CHECKLIST

When this skill is invoked, follow these steps IN ORDER:

- [ ] Detect current directory and available Ruby versions (rbenv versions)
- [ ] Detect latest stable Rails version (gem search)
- [ ] Ask user for: app name, directory, Ruby version, frontend choice, description
- [ ] Verify/install latest Rails version
- [ ] Generate Rails app with appropriate flags
- [ ] Configure bundler for vendor/bundle BEFORE bundle install
- [ ] Update Gemfile (add clockwork, niceql, rails_sql_prettifier) and run bundle install
- [ ] Initialize RSpec and configure (tmp/examples.txt, support directory)
- [ ] Update application.rb for generators and lib/ eager loading
- [ ] Update database.yml with ENV vars
- [ ] Create .env and .env.example
- [ ] Set up Redis and Sidekiq initializers
- [ ] Create AppEnvVars initializer for ENV validation
- [ ] Install and configure Devise
- [ ] Create lib/[app_name] structure
- [ ] Set up frontend based on choice
- [ ] Create Procfile.dev (with web, sidekiq, clock processes)
- [ ] Create Clockwork config (config/clock.rb)
- [ ] Create bin/setup, bin/reset_db, bin/dev, bin/doctor, bin/dev-web, bin/dev-workers
- [ ] Create Makefile
- [ ] Initialize Kamal
- [ ] Create .standard.yml
- [ ] Run bundle exec rails db:prepare
- [ ] Create structured seeds (db/seeds/development.rb, production.rb)
- [ ] Run annotate
- [ ] Generate README.md with comprehensive documentation
- [ ] Initialize git with comprehensive commit message
- [ ] Run bin/doctor to verify
- [ ] Run make dev to verify full stack starts
- [ ] Provide final output with next steps

## POST-GENERATION VERIFICATION CHECKLIST

After completing all setup steps, verify the following:

- [ ] **StandardRB is configured**: `.standard.yml` exists in project root
- [ ] **No RuboCop config**: Verify `.rubocop.yml` does NOT exist (Rails may auto-generate it)
  - If `.rubocop.yml` exists, delete it: `rm .rubocop.yml`
  - We use StandardRB instead of RuboCop
- [ ] **Gemfile has standardrb**: `bundle list | grep standardrb` shows it's installed
- [ ] **Gemfile has clockwork**: `bundle list | grep clockwork` shows it's installed
- [ ] **Linting works**: `bundle exec standardrb` runs without errors
- [ ] **Tests run**: `make test` or `bundle exec rspec` works
- [ ] **Database connected**: `bin/doctor` passes all checks
- [ ] **Vendor bundle configured**: `bundle config get path` shows `vendor/bundle`
- [ ] **Full stack starts**: `make dev` starts all processes (web, sidekiq, clock) without errors
- [ ] **Server responds**: Visit http://localhost:3000 and verify the app loads

**Remember**: Work incrementally, show progress, and verify each critical step succeeds before continuing!
