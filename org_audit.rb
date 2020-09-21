require 'set'
require 'github_api'
require 'slack-notifier'

ORGANIZATION_NAME = ENV['GPM_ORG_NAME']
GITHUB = Github.new oauth_token: ENV['GPM_GITHUB_TOKEN']
SLACK = Slack::Notifier.new ENV['GPM_SLACK_HOOK']


REPO_REGEX = %r{.*repos\/(?<user>[\w\-\_]*)\/(?<repo>[\w\-\_]*)\/.*}
LOG_FILE_NAME = 'historical_commits.log'
MENTIONS_LOG_FILE_NAME = 'historical_mentions.log'

MAX_CONTRRIBUTORS = 2
MAX_COMMITS = 5

HISTORICAL_COMMITS = Set.new
HISTORICAL_MENTIONS = Set.new
HISTORICAL_MENTIONS_REPOS_ONLY = Set.new


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

def prev_mentions
    if !File.exist? MENTIONS_LOG_FILE_NAME
        return
    end
    File.open(MENTIONS_LOG_FILE_NAME) do |f1|
        while line = f1.gets
            HISTORICAL_MENTIONS.add(line.strip)
        end
    end
    HISTORICAL_COMMITS.map { |item| HISTORICAL_MENTIONS_REPOS_ONLY.add( item.split("blob")[0]) }
end


def review_past_commits
    messages_to_publish = []
    commits_file = File.open(LOG_FILE_NAME, 'a')
    all_members = GITHUB.orgs.members.list ORGANIZATION_NAME
    all_members.each do | member|
        active_member = member['login']
        puts "Reviewing Changes by #{active_member}"
        yesterday = Date.today.prev_day
        GITHUB.gists.list({user: active_member, since: yesterday}).each do |event|
            commit_entry = "#{event.html_url}||#{active_member}"
            if !was_reported?(commit_entry, commits_file)
                message = "<!here> New Public gist from *#{active_member}*: #{event.html_url}"
                messages_to_publish.push message
                puts event.html_url
            end
        end
        GITHUB.activity.events.performed(active_member).each do |event|
            if ['PushEvent'].include?(event.type)
                case event.type
                when 'PushEvent'
                    event.payload.commits.each do |commit_data|
                        commit_entry = "#{commit_data.url}||#{active_member}"
                        message = "<!here> New public commit from *#{active_member}*: #{construct_html_url(commit_data.url)}"
                        if !was_reported?(commit_entry, commits_file)
                            if should_publish_notification?(commit_data)
                                messages_to_publish.push message
                                puts commit_data.url
                            else
                                puts "Skipped notification for public repo."
                            end
                        end
                    end
                else
                end
            end
        end
    end
    commits_file.close

    messages_to_publish.each do |message| 
        SLACK.ping message
    end
end

def was_reported?(commit_entry, commits_file)
    return true if HISTORICAL_COMMITS.include? commit_entry
    commits_file.puts commit_entry
    return false
end


def construct_html_url(html_url)
    as_array = html_url.split("/")
    "https://github.com/#{as_array[4]}/#{as_array[5]}/commit/#{as_array[7]}"
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

def review_org_mention
    mentions_file = File.open(MENTIONS_LOG_FILE_NAME, 'a')
    search_results = GITHUB.search.code(ORGANIZATION_NAME).items
    urls_with_org_mentions = search_results.map { |item| item.html_url }
    urls_with_org_mentions.each do |url|
        next if HISTORICAL_MENTIONS.include? url
        next if HISTORICAL_MENTIONS_REPOS_ONLY.include? url.split("blob")[0]
            
        notify_on_mention(url)
        puts "need to publish this one: " + url
        mentions_file.puts url
    end
end

def notify_on_mention(url)
    message = "<!here> New github entry with *#{ORGANIZATION_NAME}* mention: #{url}"
    SLACK.ping message
end

def run!
    prev_commits
    prev_mentions
    review_past_commits
    review_org_mention
end


run!