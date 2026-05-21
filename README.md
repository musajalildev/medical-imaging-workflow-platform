# Project

A Rails 8 web application for managing image processing jobs. Users can submit jobs with DICOM files, track status, and receive email notifications. Files are stored on Google Drive via a service account.

**Stack:** Ruby on Rails 8 · PostgreSQL · Delayed Job · Shakapacker

---

## Running locally

**Prerequisites:** Ruby (see `.ruby-version`), PostgreSQL, Node.js/Yarn, and an SSH key with access to the Sheffield GitLab (needed for the `epi_cas` gem).

```bash
bundle install
yarn install
cp config/database-sample.yml config/database.yml  # fill in your DB credentials

bin/rails db:create db:migrate
bin/rails db:seed   # optional

bin/shakapacker      # compile assets
bin/rails server
```

The app will be available at `http://localhost:3000`.

To start the background job worker (needed for emails):

```bash
bin/delayed_job start
```

---

## Running tests

```bash
bundle exec rspec
```

---

## Repository structure

```
app/
  controllers/   # one controller per resource
  models/        # Job, User, Report, Notification, ImageFile, etc.
  decorators/    # Draper decorators for view logic
  views/         # Haml templates
  jobs/          # ActiveJob classes (e.g. delete_job_after_delay_job.rb)
  mailers/       # UserMailer for email notifications
  packs/         # JS/CSS entry points (Shakapacker/webpack)
config/
  routes.rb      # all routes defined here
  deploy/        # Capistrano deploy config per environment
db/
  schema.rb      # current DB schema
  migrate/       # migrations
spec/            # RSpec tests (models, controllers, features, system)
```

Key models: `Job` (central), `User`, `ImageFile`, `Report`, `Notification`, `JobStatusHistory`, `CancelledJob`, `CompleteJob`.

Authorization is handled by CanCanCan (`app/models/ability.rb`). Authentication uses CAS (University of Sheffield SSO) in production and a dev session controller locally.

---

## Google Drive Setup

The application uploads job files to a Google Drive folder using a **service account**. A new owner needs to complete the following steps once before running the app.

### 1. Create a Google Drive folder

In any Google account, create a folder in Google Drive to act as the root uploads directory. You can name it anything (e.g. `App Uploads`).

Open the folder in your browser. The folder ID is the last segment of the URL:

```
https://drive.google.com/drive/folders/<FOLDER_ID>
```

### 2. Share the folder with the service account

Right-click the folder → **Share** → enter the service account's email address (found in `service_account.json` under the `"client_email"` key) and grant it **Editor** access.

### 3. Obtain the service account key

Get the `service_account.json` key file from the previous owner or generate a new one from the [Google Cloud Console](https://console.cloud.google.com/) under **IAM & Admin → Service Accounts**. Place it in the project root.

The service account must have the **Google Drive API** enabled in its associated Google Cloud project.

### 4. Configure environment variables

Create a `.env` file in the project root (copy from `.env.example`):

```
GOOGLE_DRIVE_FOLDER_ID=<your folder ID from step 1>
GOOGLE_SERVICE_ACCOUNT_PATH=/rails/service_account.json
```

`GOOGLE_SERVICE_ACCOUNT_PATH` defaults to `/rails/service_account.json` (the project root inside Docker) and can be omitted if you place the file there.

---

# Email Configuration Guide

This application uses [SendGrid](https://sendgrid.com) to send transactional emails. Follow the steps below to configure your own SendGrid account.

The current configuration uses email account softwarehutdevemail.noreply@gmail.com, it will expire on July 17th, 2026

---

## 1. Create a SendGrid Account

1. Go to [sendgrid.com](https://sendgrid.com) and sign up for a free account
2. The free tier allows up to **100 emails per day** at no cost
3. Skip the onboarding flow and go straight to the dashboard (its in the top right corner)

---

## 2. Verify a Sender Identity

Before sending emails, SendGrid requires you to verify the address you'll be sending from.

1. In the SendGrid dashboard, go to **Settings → Sender Authentication**
2. Click **Create a Sender**
3. Fill in your details — use the email address you want to send from (e.g. `noreply@yourcompany.com`)
4. SendGrid will send a verification email to that address — click the link to confirm

---

## 3. Generate an API Key

1. In the SendGrid dashboard, go to **Settings → API Keys**
2. Click **Create API Key**
3. Give it a name (e.g. your app name)
4. Select **Restricted Access** and enable **Mail Send** only
5. Click **Create & View**
6. **Copy the key immediately** — SendGrid will only show it once

---

## 4. Add the API Key to the Application

Open the Rails credentials file:

```bash
rails credentials:edit
```

Add the following (using spaces, not tabs):

```yaml
sendgrid:
  api_key: SG.your_full_api_key_here
```

Save and close the file.

---

## Troubleshooting

1. Verify It's Working

In the Rails console, confirm the key is loaded:

```ruby
Rails.application.credentials.dig(:sendgrid, :api_key)
```

This should return your API key, not `nil`.

---

2. Start the Background Job Processor

Emails are sent asynchronously via Delayed Job. Make sure it's running:

```bash
bin/delayed_job start
```

To stop it:

```bash
bin/delayed_job stop
```

For production, ensure the Delayed Job process is always running alongside your Rails server. If using a `Procfile`:

```
web: bundle exec rails server
worker: bundle exec rake jobs:work
```

---

**Emails not sending:**
- Check SendGrid **Activity** feed in the dashboard — if there's no activity, the app isn't reaching SendGrid
- Make sure Delayed Job is running (`bin/delayed_job start`)
- After updating credentials, always restart both the Rails server and Delayed Job

**API key returning nil:**
- Make sure the key is saved under `sendgrid: api_key:` in credentials (not `send_grid` with an underscore)
- Make sure you're editing the correct credentials file for your environment

**Emails going to spam:**
- Set up domain authentication in SendGrid under **Settings → Sender Authentication**
- This requires access to your domain's DNS settings