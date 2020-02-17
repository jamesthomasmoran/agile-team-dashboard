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
VIEW_ID = config['jira']['view']

# gets the active sprint id for the view
def get_active_sprint_for_view(view_id)
  http = create_http
  request = create_request("/rest/greenhopper/1.0/sprintquery/#{view_id}")
  response = http.request(request)
  sprints = JSON.parse(response.body)['sprints']
  sprints.each do |sprint|
    if sprint['state'] == 'ACTIVE'
      return sprint["id"]
    end
  end
end

# gets the active sprint naem for the view
def get_active_sprint_name_for_view(view_id)
  http = create_http
  request = create_request("/rest/greenhopper/1.0/sprintquery/#{view_id}")
  response = http.request(request)
  sprints = JSON.parse(response.body)['sprints']
  sprints.each do |sprint|
    if sprint['state'] == 'ACTIVE'
      return sprint["name"]
    end
  end
end

# returns array of issue status for each epic in sprint
def get_epics_issue_status_in_active_sprint(sprint_id,view_id)
    current_start_at = 0

     response = get_response("/rest/agile/1.0/board/#{view_id}/sprint/#{sprint_id}/issue?#{current_start_at}")
     page_result = JSON.parse(response.body)
     sprint_epic_tags = page_result['issues']

    active_sprint_epic_issues = {}

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

# returns array of number of issues iat given stage of sprint for each epic
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

# adds value to stage of epic provided issue is currently at
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

SCHEDULER.every '59m', :first_in => 0 do |job|
   epic_counts = get_issue_counts_for_epics(get_epics_issue_status_in_active_sprint(get_active_sprint_for_view(VIEW_ID),VIEW_ID))
   items = []
    sprint_name = get_active_sprint_name_for_view(VIEW_ID)

   epic_counts.each do |data|
        items.push({name: data[0], todo: data[1], inProgress: data[2], inReview: data[3], inTest: data[4], done: data[5]})
   end
json_formatted_items = items.to_json

   send_event('jiraEpicProgressBoard', {
   sprintName: sprint_name,
  items: items
   })
 end