import argparse
import io
import requests
import os
import subprocess
import sys
import zipfile
from urllib.parse import quote


def main(argv):
    # Configure parser to accept arguments
    parser = argparse.ArgumentParser(description="Download files from Gitlab and publish them.")
    parser.add_argument('-r', '--ref', help='Branch or tag name in repository. '
                        'HEAD or SHA references are not supported.', default='master')
    parser.add_argument('-c', '--channel', help='Channel where the file will be uploaded',
                        default='dev')
    args = parser.parse_args()

    publish_deb('stoqtech/private/stoq-mobile-pos', args.ref, 'build-data', args.channel)
    publish_deb('stoqtech/private/stoq-server', args.ref, 'generate_deb', args.channel)
    publish_deb('stoqtech/private/stoq', args.ref, 'generate_deb', args.channel)
    publish_deb('stoqtech/private/stoqdrivers', args.ref, 'generate_deb', args.channel)


def download_artifacts(project, ref, job):
    base_url = "https://gitlab.com/api/v4/projects/{}/jobs/artifacts/{}/download".format(
               quote(project, safe=""), quote(ref, safe=""))

    try:
        return requests.get(base_url,
                            headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")},
                            params={"job": job})
    except ValueError:
        return None


def extract_artifacts(content, extension):
    # List of the location of the installation files
    locations = []

    # Read and extract files from the downloaded content
    with zipfile.ZipFile(io.BytesIO(content)) as zipObj:
        files = zipObj.namelist()
        for f in files:
            # Make sure it's the desired extension
            if os.path.splitext(f)[1] == extension:
                zipObj.extract(f)
                locations.append(f)

    return locations


def publish_deb(project, ref, job, channel):
    # Download artifacts zip file
    response = download_artifacts(project, ref, job)

    if response.status_code is not 200:
        print("Project not found or the artifact is missing. Status code {}".format(
              response.status_code))
        return

    # Find the location of the debs
    debs = extract_artifacts(response.content, '.deb')

    if debs is None:
        return

    # Upload each extracted deb to reprepro
    for deb in debs:
        subprocess.run('reprepro --component {} --section utils includedeb xenial {}'.format(
                       channel, deb), shell=True)


if __name__ == '__main__':
    main(sys.argv[1:])
