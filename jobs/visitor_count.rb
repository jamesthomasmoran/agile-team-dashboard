require 'date'
require 'google/api_client'
require 'yaml'


# Update these to match your own apps credentials
# set ENV GOOGLE_APPLICATION_CREDENTIALS = "/home/ubuntu/google-service-account.json"

# load configuration
config = YAML.load_file('config.yml')

service_account_email = config['google-analytics']['service-account-email'] # Email of service account
key_file = config['google-analytics']['key-file'] # File containing your private key
key_secret = config['google-analytics']['key-secret'] # Password to unlock private key
profileID = config['google-analytics']['profile-id']
app_version = config['google-analytics']['application-version']
app_name = config['google-analytics']['application-version']
p service_account_email
# Get the Google API client
client = Google::APIClient.new(:application_name => app_name,
  :application_version => app_version)
p service_account_email
# Load your credentials for the service account
key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, key_secret)

client.authorization = Signet::OAuth2::Client.new(
  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
  :audience => 'https://accounts.google.com/o/oauth2/token',
  :scope => 'https://www.googleapis.com/auth/analytics.readonly',
  :issuer => service_account_email,
  :signing_key => key)


# Start the scheduler
SCHEDULER.every '10s', :first_in => 0 do

  # Request a token for our service account
    client.authorization.fetch_access_token!

    # Get the analytics API
    analytics = client.discovered_api('analytics','v3')


    # Start and end dates
    startDate = DateTime.now.strftime("%Y-%m-%d") # first day of current month
    endDate = DateTime.now.strftime("%Y-%m-%d")  # now

    # Execute the query
    visitCount = client.execute(:api_method => analytics.data.realtime.get, :parameters => {
      'ids' => "ga:" + profileID.to_s,
      'dimensions' => 'ga:medium',
          'metrics' => "ga:activeVisitors"
      #'start-date' => startDate,
      #'end-date' => endDate,
      # 'dimensions' => "ga:month",
      #'metrics' => "ga:visitors",
      # 'sort' => "ga:month"
    })

    # Update the dashboard
    # Note the trailing to_i - See: https://github.com/Shopify/dashing/issues/33
    send_event('visitor_count',   { current: visitCount.data.totalsForAllResults["ga:activeVisitors"] })
  end