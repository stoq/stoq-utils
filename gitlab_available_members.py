import requests
import os


def get_members(project):
    # Collect a list of members of a project
    print('\nGetting members...')
    gitlab_url = "https://gitlab.com/api/v4/projects/{}/members/all".format(project)
    members = requests.get(gitlab_url,
                           headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")}).json()

    return members


def main():
    project = "stoqtech/private/bdil".replace('/', '%2F')
    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/".format(project)
    issues = []
    assignees = []
    page = 1

    # Read issues and collect assignees of those with "status: Doing" label
    while True:
        print('Reading issues of page', page)
        params = dict(
            scope='all',
            state='opened',
            label_name='status: Doing',
            page=str(page),
            per_page='100',
        )
        page += 1
        issues = requests.get(
            gitlab_url, headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")},
            params=params).json()
        if issues != []:
            for issue in issues:
                if 'status: Doing' in issue['labels']:
                    if issue['assignee'] is not None:
                        assignees.append(issue['assignee'])
        else:
            break

    # Collect busy members
    busy_members = []
    duplicated_busy_members = []
    for assignee in assignees:
        if assignee['name'] not in busy_members:
            busy_members.append(assignee['name'])
        else:
            duplicated_busy_members.append(assignee['name'])

    # Exclude a group of members
    members = get_members(project)
    filtered_members = []
    excluded_members = ['andrefior', 'Stocaio', 'kikoreis', 'devstoq', 'lcouto',
                        'rafaelredivo', 'romaia', 'gerga']
    for member in members:
        if (member['username'] not in excluded_members and
           member['name'] not in filtered_members):
            filtered_members.append(member['name'])

    # Show members that can be assigned
    print('\nBdiL project members:', filtered_members)
    available_members = []
    for member in filtered_members:
        if member not in busy_members:
            available_members.append(member)

    # Show available members and those doing more than one issue at a time
    print('\nAvailable members:', available_members)
    if duplicated_busy_members != []:
        print('\nObs:')
        for member in duplicated_busy_members:
            print('{} is doing more than one issue'.format(member))


if __name__ == '__main__':
    main()
