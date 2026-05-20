# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

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
