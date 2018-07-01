require 'set'

require 'github_api'
require 'slack-notifier'

organization_name = ENV['GPM_ORG_NAME']
github = Github.new oauth_token: ENV['GPM_GITHUB_TOKEN']
slack = Slack::Notifier.new ENV['GPM_SLACK_HOOK']

all_members = github.orgs.members.list organization_name

LOG_FILE_NAME = 'historical_commits.log'

HISTORICAL_COMMITS = Set.new
if File.exist? LOG_FILE_NAME
    File.open(LOG_FILE_NAME) do |f1|
        while line = f1.gets
            HISTORICAL_COMMITS.add(line.strip)
        end
    end
end

COMMITS_FILE = File.open(LOG_FILE_NAME, 'a')

all_members.each do | member|
    active_member = member['login']
    puts "Reviewing Changes by #{active_member}"
    github.activity.events.performed(active_member).each do |event|
        if ['PushEvent'].include?(event.type)
            case event.type
            when 'PushEvent'
                event.payload.commits.each do |commit_data|
                    commit_entry = "#{commit_data.url}||#{active_member}"
                    if !HISTORICAL_COMMITS.include? commit_entry
                        message = "<!here> New public commit from *#{active_member}*: #{commit_data.url}"
                        slack.ping message
                        puts commit_data.url
                        COMMITS_FILE.puts commit_entry
                    end
                end
            else
            end
        end
    end
end

COMMITS_FILE.close
