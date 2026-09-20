# Medical Imaging Workflow Platform

A full-stack **Ruby on Rails 8** application for managing medical imaging processing workflows.

The platform allows clients to submit processing jobs containing **DICOM medical imaging files**, track their progress through a defined workflow, and receive completed reports. Operators manage the processing of submitted jobs, while administrators manage users and the wider platform.

The application was developed collaboratively as a six-person software engineering team project at the **University of Sheffield**.

---

## Key Features

* DICOM imaging job submission and management
* Multi-stage job processing workflow
* Client, operator and administrator user roles
* Role-based authorization
* Job status tracking and history
* File and report management
* Google Drive file storage
* Automated transactional email notifications
* Background job processing
* University CAS authentication
* PostgreSQL persistence
* Automated RSpec test suite
* Production deployment configuration

---

## How It Works

The application manages the lifecycle of a medical imaging processing job.

```text
Client
   │
   ▼
Submit Processing Job
   │
   ├── DICOM Files
   └── Job Information
   │
   ▼
Job Created
   │
   ▼
Operator Processing
   │
   ├── Status Updates
   ├── File Management
   └── Processing Workflow
   │
   ▼
Report Generated
   │
   ▼
Client Receives Completed Report
```

Users receive notifications as jobs progress through the system.

Different functionality is exposed depending on the user's role.

### Clients

Clients can submit imaging jobs, upload the associated files, monitor job progress and access completed reports.

### Operators

Operators manage the processing side of the workflow and update jobs as they progress.

### Administrators

Administrators manage the wider platform and its users.

---

## Architecture

The application follows the standard Rails MVC architecture.

```text
                    ┌─────────────────┐
                    │     Browser     │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Rails Controllers│
                    └────────┬────────┘
                             │
                 ┌───────────┴───────────┐
                 ▼                       ▼
        ┌────────────────┐      ┌────────────────┐
        │ Rails Models   │      │ Rails Views    │
        └───────┬────────┘      │     Haml       │
                │               └────────────────┘
                ▼
        ┌────────────────┐
        │   PostgreSQL   │
        └────────────────┘

                │
       External Services
                │
       ┌────────┴─────────┐
       ▼                  ▼
┌──────────────┐   ┌──────────────┐
│ Google Drive │   │   SendGrid   │
│ File Storage │   │    Email     │
└──────────────┘   └──────────────┘
```

Background tasks such as email delivery are handled asynchronously using **Delayed Job**.

---

## Job Workflow

`Job` is the central model within the application.

Supporting models include:

* `User`
* `ImageFile`
* `Report`
* `Notification`
* `JobStatusHistory`
* `CancelledJob`
* `CompleteJob`

The application records changes to jobs as they move through the processing workflow, providing a history of status changes.

---

## Authentication & Authorization

Authentication in production uses the **University of Sheffield CAS single sign-on system**.

A development authentication mechanism is provided for local development.

Authorization is implemented using **CanCanCan**, allowing functionality and resources to be restricted according to user roles.

---

## File Storage

Uploaded job files are stored using **Google Drive**.

The application integrates with the Google Drive API through a service account, allowing uploaded files to be organised and accessed as part of the processing workflow.

Sensitive credentials and service-account keys are **not included in the repository** and must be configured separately for a local deployment.

---

## Email Notifications

The application sends transactional emails using **SendGrid**.

Email delivery is performed asynchronously through **Delayed Job**, preventing email operations from blocking normal web requests.

Configuration values and API credentials must be supplied separately and are not stored in source control.

---

## Testing

The project uses **RSpec** for automated testing.

The test suite includes coverage across areas such as:

* Models
* Controllers
* Features
* System behaviour
* Job workflows
* User functionality
* External service interactions

External services such as Google Drive can be isolated from automated tests so that running the test suite does not create or modify real cloud resources.

Run the test suite with:

```bash
bundle exec rspec
```

---

## Technologies

### Backend

* Ruby
* Ruby on Rails 8
* PostgreSQL
* ActiveJob
* Delayed Job

### Frontend

* Haml
* JavaScript
* Shakapacker
* Webpack

### Authentication & Authorization

* CAS authentication
* CanCanCan

### External Services

* Google Drive API
* SendGrid

### Testing

* RSpec
* Capybara

### Development & Collaboration

* Git
* GitLab
* GitHub

---

## Repository Structure

```text
app/
├── controllers/     # Request handling and application logic
├── models/          # Job, User, Report, Notification, etc.
├── decorators/      # Presentation/view logic
├── views/           # Haml templates
├── jobs/            # Background jobs
├── mailers/         # Email notification logic
└── packs/           # JavaScript/CSS entry points

config/
├── routes.rb        # Application routes
└── deploy/          # Deployment configuration

db/
├── schema.rb
└── migrate/

spec/
├── models/
├── controllers/
├── features/
└── system/
```

---

## Running Locally

### Prerequisites

The application requires:

* Ruby (see `.ruby-version`)
* PostgreSQL
* Node.js
* Yarn

Install the application dependencies:

```bash
bundle install
yarn install
```

Create your local database configuration:

```bash
cp config/database-sample.yml config/database.yml
```

Configure the appropriate local database credentials and then initialise the database:

```bash
bin/rails db:create
bin/rails db:migrate
```

Optional development seed data can be created with:

```bash
bin/rails db:seed
```

Compile the frontend assets:

```bash
bin/shakapacker
```

Start the Rails application:

```bash
bin/rails server
```

The application will then be available at:

```text
http://localhost:3000
```

Background jobs can be started with:

```bash
bin/delayed_job start
```

> Some functionality depends on external services and university infrastructure and therefore requires additional configuration that is not distributed with this repository.

---

## Security & Privacy Considerations

Because the application was designed around medical imaging workflows, data protection was an important consideration during development.

DICOM files can contain patient metadata within their headers. The project specification assumed files would be anonymised before entering the system.

Reflecting on the design highlighted an important distinction between **assuming that incoming data has been anonymised** and actively verifying that it has been anonymised.

A production implementation could strengthen this boundary through measures such as:

* DICOM metadata validation
* Removal of identifying metadata during upload
* Explicit anonymisation confirmation
* Stronger auditing of access to imaging data
* Privacy-focused logging and monitoring

This was an important lesson from the project: security and privacy requirements should influence system design directly rather than appearing only as consequences of other implementation decisions.

---

## Team Development

This application was developed collaboratively by a **six-person software engineering team**.

Development involved:

* Feature branches
* Merge requests
* Code review
* Collaborative Git workflows
* Requirements gathering
* Client communication
* Testing and quality assurance
* Deployment
* Iterative development

The project's original Git history has been retained to accurately represent its collaborative development.

Working on a repository of this size also provided practical experience managing concurrent development and merge conflicts across a large number of branches.

---

## My Contribution

My contributions included work across the application's development and testing, with particular experience around:

* Ruby on Rails development
* Automated testing with RSpec
* System and integration testing
* Job and user functionality
* Google Drive integration testing
* Isolating external services during automated tests
* Debugging and resolving integration issues
* Git-based collaborative development
* Testing and quality assurance

The project also gave me experience working within a larger existing codebase where features developed by multiple team members needed to integrate into a single production application.

---

## What I Learned

This project provided experience beyond simply implementing application features.

Some of the most important lessons involved:

**Collaborative Git workflows**
Working across many concurrent branches demonstrated why teams need an agreed branching and merging strategy rather than relying only on individual Git knowledge.

**Testing external integrations**
Services such as Google Drive demonstrated the importance of isolating external dependencies during automated testing.

**Software engineering as a team process**
Clear communication, agreed working practices and code review proved as important to successful delivery as the implementation itself.

**Privacy by design**
Working with a medical-imaging workflow highlighted why privacy and security assumptions need to be explicitly examined during system design.

---

## Academic Context

Developed as part of the **COM213 Software Hut** module at the **University of Sheffield**.

This was a collaborative team project developed in response to a client brief. The repository retains its original contributor and commit history to accurately represent the collaborative nature of the work.
