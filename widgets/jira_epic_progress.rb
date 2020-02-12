# Displays the status of the current open sprint

require 'net/http'
require 'json'
require 'time'

# Loads configuration file
config = YAML.load_file('config.yml')
USERNAME = config['jira']['username']
PASSWORD = config['jira']['api-key']
JIRA_URI = URI.parse(config['jira']['url'])
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
      print sprint['id']
      return sprint['id']
    end
  end
end

# gets all epics that are in active sprint
def get_epics_in_active_sprint(sprint_id,view_id)

     response = get_response("/rest/agile/1.0/board/170/sprint/1631/issue?startAt=0")
     page_result = JSON.parse(response.body)
     issue_array = page_result['issues']

    active_sprint_epic_ids = []
    sprint_epic_tags = issue_array
    sprint_epic_tags.each do |epic|
        if !epic['fields']['epic'].nil?
           active_sprint_epic_ids.push(epic["id"])
        end

    end

    return active_sprint_epic_ids
end

# gets all epic names, completed tasks, total tasks and percentage completion that are incomplete or worked on in current sprint
def get_epics_details(sprint,view_id)
    epic_details = [[], [], []]

    active_sprint_epics = get_epics_in_active_sprint(sprint,view_id)
    http = create_http
    request = create_request("/rest/greenhopper/1.0/xboard/plan/backlog/epics?&rapidViewId=#{view_id}")
    response = http.request(request)
    all_epics = JSON.parse(response.body)['epics']

    all_epics.each do |epic|
        if active_sprint_epics.include?(epic['epicStats']['id'])
            epic_details[0].push(epic['epicLabel'])
            epic_details[1].push(epic['epicStats']['done'])
            epic_details[2].push(epic['epicStats']['totalIssueCount'])
        end
    end
    return epic_details
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

# read list index from created json file
def read_list_index()
    list_index = 0
    file = File.open("jira-epic-progress.json","r")
    list_index =JSON.parse(file.read)['index']
    return list_index
end

# write incremented list index to created json file
def write_list_index(list_index)
    file = File.open("jira-epic-progress.json","w")
    index = {"index" => (list_index + 1)}
    file.write(index.to_json)
end


SCHEDULER.every '59s', :first_in => 0 do
  returned_epic = ["No Epics", 0, 0]
  epics = get_epics_details(get_active_sprint_for_view(VIEW_ID),VIEW_ID)
  list_index = read_list_index()
  #if(epics.length() == 0)

  #elsif
    if list_index >= epics[0].length()
       list_index = 0
    end
    returned_epic[0] = epics[0][list_index]
    returned_epic[1] = epics[1][list_index]
    returned_epic[2] = epics[2][list_index]
    write_list_index(list_index)
  #end

  send_event('epicProgress', {
      epicName:returned_epic[0],
      doneTasks: returned_epic[1],
      totalTasks: returned_epic[2],
      index: get_epics_in_active_sprint(170, VIEW_ID),
      sprint_id: get_active_sprint_for_view(VIEW_ID),
      epics:epics[0][0]
  })
end