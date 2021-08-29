# Freshdesk to Zendesk Migration
Migrate your Freshdesk users, tickets and conversations / comments to Zendesk.
## Setup
Before migrating tickets you need to set up the environment and install the necessary packages.
### Install Ruby
Follow this [link](https://rubyreferences.github.io/rubyref/intro/installation.html) to install Ruby on your system. The version of Ruby used during development was 2.7.1, to use other versions of ruby you may need to update the Gemfile.
### Install MySQL
MySQL is used as a relational database management system, which is used to store tickets locally for successful ticket migration, monitoring progress, and post-migration verification.
### Install Dependencies
After installation of Ruby and MySQL, run the below command to install the requirements.
```sh
bundle install
```
### Configure
Open `fd2zd.rb` file and update the configurations. For **Freshdesk** you will need to update the following configurations:
- `subdomain` - Subdomain of Freshdesk account
- `api_token` - Your Freshdesk API Key
- `include_conversations` - Import conversations of each ticket as well
- `filter` - Define criteria to migrate only required tickets
- `tickets_updated_since` - This should be set to any date which is older than your Freshdesk account creation date

For **Zendesk**, update the following configurations:
- `subdomain` - Subdomain of your Zendesk account
- `api_token` - API Token created in your Zendesk account
- `admin_email` - Admin Email of Zendesk account.
- `jobs_count` - Number of Import Jobs to start in parallel to speed up the process.

For **Database** you will need to update these configurations:
- `adapter` - Database adapter
- `encoding` - Character Set Encoding
- `username` - Database Username
- `password` - Database Password
- `database` - Database Name

### Setup Zendesk Account
Before migration, you should set up Zendesk account for migration.
- Disable the welcome email notification for new end users.
- Create a [sandbox](https://support.zendesk.com/hc/en-us/articles/203661826-Testing-changes-in-your-standard-sandbox) instance to test the migration.

## Migrate Data
### Load required data in database
Run the command below to create and set up a database.
```sh
bundle exec rake db:prepare
```
After the database is prepared, we can load tickets in the database.
```sh
bundle exec rake fd2zd:load_tickets
```
Load agents in the database as well:
```sh
bundle exec rake fd2zd:load_resources CLASS=Agent
```
To load contacts in the database you have two options
1. Load all contacts
2. Load only required contacts (having tickets that will be migrated to Zendesk)

To load all contacts:
```sh
bundle exec rake fd2zd:load_resources CLASS=Contact
```
To load only required contacts:
```sh
bundle exec rake fd2zd:load_required_contacts
```
### Import Users
Once you have required users in the database, you can import them into your Zendesk account. A user is only imported if it doesn't already exist in Zendesk.
#### User Fields Mapping
Before migrating users, you may want to customize the mapping of the fields. To do so, open the file `lib/converters/user_converter.rb`. The `UserConverter` class can be changed to customize the migration of users.

#### Import
Run the command below to import users.
```sh
bundle exec rake fd2zd:import_users
```
If the number of users to import is large, you may want to monitor the progress. Open a new terminal tab and run this command to monitor progress.
```sh
bundle exec rake fd2zd:users_import_job_status
```
After completion of the users import job, you can verify the migration by running this command:
```sh
bundle exec rake fd2zd:verify_users_import
```
### Import Tickets
After you have imported all required users from your Freshdesk account to Zendesk, you are ready to import tickets.

#### Ticket Fields Mapping
Like `UserConverter`, the `TicketConverter` class converts Freshdesk ticket into Zendesk ticket. The class is defined in file `lib/converters/ticket_converter.rb`. You can customize this class to control the mapping of the fields.

**Important:** In `lib/converters/ticket_converter.rb` file, enter default values for `assignee_id`, `requester_id`, `author_id`, otherwise your tickes will not be imported if your Freshdesk agent / customer does not exists in Zendesk.

#### Import
Once the `TicketConverter` class is ready, you can run the below command to start migration.<br/>

**Note:** The tickets imported will be [archived](https://support.zendesk.com/hc/en-us/articles/203657756-About-ticket-archiving) immediately, ticket status is set to 'closed' by default (can be changed in `TicketConverter` class) and `'freshdesk-import'` tag is added to each ticket.
```sh
bundle exec rake fd2zd:import_tickets
```
To monitor progress of tickets import, you can run this command in a new terminal:
```sh
bundle exec rake fd2zd:tickets_import_job_status
```
To verify the tickets import, after the import job is completed, run this command:
```sh
bundle exec rake fd2zd:verify_tickets_import
```

To customize the import job further, you can edit the `lib/zendesk/tickets_import_service.rb` file.
