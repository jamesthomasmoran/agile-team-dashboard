# Displays the status of the current open sprint

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

     response = get_response("/rest/agile/1.0/board/170/sprint/1163/issue?startAt=#{current_start_at}")
     page_result = JSON.parse(response.body)
     issue_array = page_result['issues']

    active_sprint_epic_issues = {}
    sprint_epic_tags = issue_array
    sprint_epic_tags.each do |epic|
        if !epic['fields']['epic'].nil?
            epic_id = epic['fields']['epic']["id"]
            if !active_sprint_epic_issues.key?(epic_id)
                active_sprint_epic_issues[epic_id] = {}
                end
            active_sprint_epic_issues[epic_id].push(epic["fields"]["status"]["statusCategory"]["name"])
        end

    end

    return active_sprint_epic_issues
end

def get_issue_counts_for_epics(issues)
    index = 0
    issues.each_key do |issue_array|
    issue_count_array.push([])
    issue_array.each do |issue|
          accumulate_issue_information(issue, issue_count_array, issue_sp_count_array, index)
        end
     index = index + 1
     end
def accumulate_issue_information(issue,issue_count_array)


    case issue
        when "To Do"
            issue_count_array[index][0] = issue_count_array[index][0] + 1

        when "Work in progress"
            issue_count_array[index][1] = issue_count_array[index][1] + 1

        when "In Review"
            issue_count_array[index][2] = issue_count_array[index][2] + 1

        when "Test"
            issue_count_array[index][3] = issue_count_array[index][3] + 1

        when "Done"
            issue_count_array[index][4] = issue_count_array[index][4] + 1

        else
          puts "ERROR: wrong issue status"
      end

      issue_count_array[index][5] = issue_count_array[index][5] + 1

    end


# gets issues in each status
def get_issues_per_status(view_id, sprint_id, issue_count_array, issue_sp_count_array)
  current_start_at = 0

  begin
    response = get_response("/rest/agile/1.0/board/#{view_id}/sprint/#{sprint_id}/issue?startAt=#{current_start_at}")
    page_result = JSON.parse(response.body)
    issue_array = page_result['issues']

    issue_array.each do |issue|
      accumulate_issue_information(issue, issue_count_array, issue_sp_count_array)
    end

    current_start_at = current_start_at + page_result['maxResults']
  end while current_start_at < page_result['total']
end

# accumulate issue information
def accumulate_issue_information(issue, issue_count_array, issue_sp_count_array)
  case issue['fields']['status']['name']
    when "To Do"
      if !issue['fields']['issuetype']['subtask']
        issue_count_array[0] = issue_count_array[0] + 1
      end
      if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
        issue_sp_count_array[0] = issue_sp_count_array[0] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
      end
    when "Work in progress"
      if !issue['fields']['issuetype']['subtask']
        issue_count_array[1] = issue_count_array[1] + 1
      end
      if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
        issue_sp_count_array[1] = issue_sp_count_array[1] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
      end
    when "In Review"
      if !issue['fields']['issuetype']['subtask']
        issue_count_array[2] = issue_count_array[2] + 1
      end
      if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
        issue_sp_count_array[2] = issue_sp_count_array[2] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
      end
    when "Test"
      if !issue['fields']['issuetype']['subtask']
        issue_count_array[3] = issue_count_array[3] + 1
      end
      if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
        issue_sp_count_array[3] = issue_sp_count_array[3] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
      end
    when "Done"
      if !issue['fields']['issuetype']['subtask']
        issue_count_array[4] = issue_count_array[4] + 1
      end
      if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
        issue_sp_count_array[4] = issue_sp_count_array[4] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
      end
    else
      puts "ERROR: wrong issue status"
  end

  issue_count_array[5] = issue_count_array[5] + 1
  if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
    issue_sp_count_array[5] = issue_sp_count_array[5] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
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

issue_count_array = Hash.new({ value: 0 })

SCHEDULER.every '1h', :first_in => 0 do
    issues = []
    issues.push({
    label: "test1",
    value: 2
    })
   test1 = [{:label=>"Count", :value=>10}, { :label=>"Sort", :value=>30}]
   test2 = {"name" => "test2", "todo" => 2, "done" => 1}
  #issue_count_array = get_issue_counts_for_epics(get_epics_in_active_sprint(get_active_sprint_for_view(VIEW_ID),VIEW_ID))
   issue_count_array["test1"] = { label: "test1", value: "2"}
   issue_count_array["test2"] = { label: "test2", todo: "2", done: "1"}
   issue_count_array.to_json
  send_event('boardStatus', {
      items: issues,
       toDoCount: test1["name"],
      # inProgressCount: issue_count_array[1],
      # inReviewCount: issue_count_array[2],
      # inTestCount: issue_count_array[3],
      # doneCount: issue_count_array[4],


  })
end
end

