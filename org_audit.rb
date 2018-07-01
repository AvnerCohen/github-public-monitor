require 'set'

require 'github_api'
require 'slack-notifier'

ORGANIZATION_NAME = ENV['GPM_ORG_NAME']
GITHUB = Github.new oauth_token: ENV['GPM_GITHUB_TOKEN']
SLACK = Slack::Notifier.new ENV['GPM_SLACK_HOOK']


REPO_REGEX = %r{.*repos\/(?<user>[\w\-\_]*)\/(?<repo>[\w\-\_]*)\/.*}
LOG_FILE_NAME = 'historical_commits.log'

MAX_CONTRRIBUTORS = 2
MAX_COMMITS = 3

HISTORICAL_COMMITS = Set.new

def prev_commits
    if !File.exist? LOG_FILE_NAME
        return
    end
    File.open(LOG_FILE_NAME) do |f1|
        while line = f1.gets
            HISTORICAL_COMMITS.add(line.strip)
        end
    end
end



def review_past_commits
    commits_file = File.open(LOG_FILE_NAME, 'a')
    all_members = GITHUB.orgs.members.list ORGANIZATION_NAME
    all_members.each do | member|
        active_member = member['login']
        puts "Reviewing Changes by #{active_member}"
        GITHUB.activity.events.performed(active_member).each do |event|
            if ['PushEvent'].include?(event.type)
                case event.type
                when 'PushEvent'
                    event.payload.commits.each do |commit_data|
                        commit_entry = "#{commit_data.url}||#{active_member}"
                        if !HISTORICAL_COMMITS.include? commit_entry
                            message = "<!here> New public commit from *#{active_member}*: #{commit_data.url}"
                            if should_publish_notification?(commit_data)
                                SLACK.ping message
                                puts commit_data.url
                            else
                                puts "Skipped notification to public repo."
                            end
                            commits_file.puts commit_entry
                        end
                    end
                else
                end
            end
        end
    end
    commits_file.close
end


def should_publish_notification?(commit_data)
    ## Set of heuritics to avoid publishing events where not needed
    url = commit_data.url
    matches = url.match(REPO_REGEX)
    # Check if there are more than 2 contributors on the repo
    if matches and matches[:repo]
        stats = GITHUB.repos.stats(repo: matches[:repo] ,user:matches[:user])
        contributors_count = stats.contributors.size
        return false if contributors_count > MAX_CONTRRIBUTORS
        commits = GITHUB.repos.commits(repo: matches[:repo] ,user:matches[:user])
        return false if commits.list.size > MAX_COMMITS
    end

    return true
end

#
def run!
    prev_commits
    review_past_commits
end


run!