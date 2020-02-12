# Displays the status of the current open sprint
require 'yaml'
require 'net/http'
require 'json'
require 'time'

# Loads configuration file
config = YAML.load_file('config.yml')
USERNAME = config['jira']['username']
PASSWORD = config['jira']['api-key']
JIRA_URI = URI.parse(config['jira']['url'])
STORY_POINTS_CUSTOMFIELD_CODE = config['jira']['customfield']['storypoints']
VIEW_ID = config['jira']['view']

# gets the view for a given view id
def get_view_for_viewid(view_id)
  http = create_http
  request = create_request("/rest/greenhopper/1.0/rapidviews/list")
  response = http.request(request)
  views = JSON.parse(response.body)['views']
  views.each do |view|
    if view['id'] == view_id
      return view
    end
  end
end

# gets the active sprint for the view
def get_active_sprint_for_view(view_id)
  http = create_http
  request = create_request("/rest/greenhopper/1.0/sprintquery/#{view_id}")
  response = http.request(request)
  sprints = JSON.parse(response.body)['sprints']
  sprints.each do |sprint|
    if sprint['state'] == 'ACTIVE'
      return sprint
    end
  end
end

# gets all epics that are in active sprint
def get_epics_in_active_sprint(sprint_id,view_id)
    current_start_at = 0

     response = get_response("/rest/agile/1.0/board/170/sprint/1631/issue?startAt=0")
     page_result = JSON.parse(response.body)
     issue_array = page_result['issues']

    active_sprint_epic_issues = {}
    sprint_epic_tags = issue_array
    active_sprint_epic_issues["Unassigned"] = []
    active_sprint_epic_issues["Bugs"] = []
    sprint_epic_tags.each do |epic|
        if !epic['fields']['epic'].nil?
            epic_id = epic['fields']['epic']["name"]
            if !active_sprint_epic_issues.key?(epic_id)
               active_sprint_epic_issues[epic_id] = []
            end
            active_sprint_epic_issues[epic_id].push(epic["fields"]["status"]["name"])

        else
            if epic["fields"]["issuetype"]["name"] == "Bug"
                active_sprint_epic_issues["Bugs"].push(epic["fields"]["status"]["name"])

            else
            active_sprint_epic_issues["Unassigned"].push(epic["fields"]["status"]["name"])
            end
        end
    end

    return active_sprint_epic_issues
end

def get_issue_counts_for_epics(issues)
    issue_count_array = []
    index = 0
    issues.each do |key, value|
    issue_count_array.push([key,0,0,0,0,0])
    value.each do |issue|
          accumulate_issue_information(issue, issue_count_array, index)
        end
     index = index + 1
     end

     return issue_count_array
 end
def accumulate_issue_information(issue,issue_count_array,index)


    case issue
        when "To Do"
            issue_count_array[index][1] = issue_count_array[index][1] + 1

        when "In Progress"
            issue_count_array[index][2] = issue_count_array[index][2] + 1

        when "In Review"
            issue_count_array[index][3] = issue_count_array[index][3] + 1

        when "Test"
            issue_count_array[index][4] = issue_count_array[index][4] + 1

        when "Done"
            issue_count_array[index][5] = issue_count_array[index][5] + 1

        else
          puts "ERROR: wrong issue status"
      end

      #issue_count_array[index][5] = issue_count_array[index][5] + 1


end



# create HTTP
def create_http
  http = Net::HTTP.new(JIRA_URI.host, JIRA_URI.port)
  if ('https' == JIRA_URI.scheme)
    http.use_ssl     = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  return http
end

# create HTTP request for given path
def create_request(path)
  request = Net::HTTP::Get.new(JIRA_URI.path + path)
  if USERNAME
    request.basic_auth(USERNAME, PASSWORD)
  end
  return request
end

# gets the response after a request
def get_response(path)
  http = create_http
  request = create_request(path)
  response = http.request(request)

  return response
end




SCHEDULER.every '59m' do
   random_buzzword = get_issue_counts_for_epics(get_epics_in_active_sprint(0,170))
   buzzword_counts = []
   index = 0
   random_buzzword.each do |test|

    buzzword_counts.push( { name: test[0], todo: test[1], inProgress: test[2], inReview: test[3], inTest: test[4], done: test[5] })

   end
   p buzzword_counts[index]
   send_event('buzzwords', {
  items: buzzword_counts.values
   })
 end
