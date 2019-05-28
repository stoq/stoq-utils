##
## This code runs on Jenkins' machine using its environment variables to get Gerrit data.
## Its functionality is to get a patch from Gerrit and make comments on Gitlab's related issue.
## For now, the code only posts on Gitlab the URL of Gerrit's patch.
##

import re
import requests
import os


def main():
    # Only add the comment to gitlab for the first patchset
    if int(os.getenv("GERRIT_PATCHSET_NUMBER")) > 1:
        return None

    data = os.getenv("GERRIT_CHANGE_COMMIT_MESSAGE")
    project, issue = re.search("Fixes: https://gitlab.com/(.*)/issues/(\d+)", data).groups()
    assert project and issue, (project, issue)

    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/{}/notes".format(
                 project.replace('/', '%2F'), issue)
    requests.post(gitlab_url,
                  headers={"Private-Token": os.getenv("GITLAB_API_TOKEN")},
                  data={"body": os.getenv("GERRIT_CHANGE_URL")})


if __name__ == '__main__':
    main()
