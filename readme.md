# Github Secrets Public Monitor

A simple script to loop over all organization members, and search for each commit done by the team, publishing any new commit to a slack channel for a manual review


### Why?

There are many very good tools to search for secrets in github repositories.

* https://github.com/awslabs/git-secrets
* https://github.com/anshumanbh/git-all-secrets
* https://github.com/zricethezav/gitleaks
* https://github.com/dxa4481/truffleHog
* https://github.com/auth0/repo-supervisor

All of these uses variety of methods covering search git history, scanning large repos and searching high entropy strings for passwords and strings.

So basically, a black listing approach, searching what could be a leaked password.

What I have seen is that usually such leaks will be wrong commits to public repos or gists, sometimes not part of the github org, and private repos are a different concern.

For a small enough organization scanning manually each and every commit, sometimes can be done, and might be a simpler solution in some cases.

###How to run?


```sh
GPM_ORG_NAME=YOUR_ORG_NAME GPM_SLACK_HOOK=HOOK_URL GPM_GITHUB_TOKEN=GITHUB_TOKEN ruby org_audit.rb
```

**GITHUB_TOKEN** - should only have permission to read organization members, that's it.

**GPM_SLACK_HOOK**  - Incoming Slack Hook to a predefined channel.

**GPM_ORG_NAME** - You organization name

Once defined, this can be run on some schedule to keep monitor the organizations' public commits.
