##
## This code runs on Jenkins' machine using its environment variables to get Gerrit data.
## Its functionality is to get a patch from Gerrit and make comments on Gitlab's related issue.
## For now, the code only posts on Gitlab the URL of Gerrit's patch.
##

import re
import requests
import asyncio
import os
import aiohttp
import json
from gidgetlab.aiohttp import GitLabAPI


async def main():
    # Only add the comment to gitlab for the first patchset
    if int(os.getenv("GERRIT_PATCHSET_NUMBER")) > 1:
        return None

    data = os.getenv("GERRIT_CHANGE_COMMIT_MESSAGE")
    project, issue = re.search("Fixes: https://gitlab.com/(.*)/issues/(\d+)", data).groups()
    assert project, project
    assert issue, issue
    gitlab_url = "/projects/{}/issues/{}/notes/".format(project.replace('/', '%2F'), issue)

    async with aiohttp.ClientSession() as session:
        gl = GitLabAPI(session, "devstoq", access_token=os.getenv("GITLAB_API_TOKEN"))
        await gl.post(gitlab_url, data={"body": os.getenv("GERRIT_CHANGE_URL")})

if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
