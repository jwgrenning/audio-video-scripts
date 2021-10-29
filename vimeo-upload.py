import os
import sys
import vimeo
import json
import logging

logging.basicConfig(filename='vimeo-upload.log', 
    format='%(asctime)s - %(message)s',
    level=logging.INFO)

my_token = os.environ['VIMEO_ACCESS_TOKEN']
my_secret = os.environ['VIMEO_CLIENT_SECRET']
my_id = os.environ['VIMEO_CLIENT_ID']

# print "Client ID: " + my_id
# print "Secret: " + my_secret
# print "Token: " + my_token


v = vimeo.VimeoClient(
    token=my_token,
    key=my_id,
    secret=my_secret
)

about_me = v.get('/me')

assert about_me.status_code == 200

# print(json.dumps(about_me.json(), indent=2))
def show(message):
    print message
    logging.info(message)

def upload_video(video_path, title, description, thumb):
    show("Uploading: NO VIDEO ID")
    show("----> Path: " + video_path)
    show("----> Title: " + title)
    show("----> Description: " + description)
    uri = v.upload(video_path, data={
    'name': title,
    'description': description
    })
    show("----> URI: " + uri)
    show("----> Thumb: " + thumb)
    v.upload_picture(uri, thumb, activate=True)
    show("------------------------------------------------------------")
    return uri


def replace_video(video_id, video_path, title, description, thumb):
    show("Replacing: " + video_id)
    show("----> Path: " + video_path)
    show("----> Title: " + title)
    show("----> Description: " + description)
    uri = v.replace(
            video_uri='/videos/' + video_id,
            filename=video_path
            )
    v.patch(uri, data =
            {
            'name': title, 
            'description': description
            }
        )
    show("----> URI: " + uri)
    show("----> Thumb: " + thumb)
    v.upload_picture(uri, thumb, activate=True)
    show("------------------------------------------------------------")
    return uri


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print "usage: {0} normalized-vimeo-file".format(sys.argv[0], len(sys.argv))
        exit(1)

    video_path = sys.argv[1]
    video_file = video_path.split('/')[-1]
    parts = video_path.split(".mp4.")
    thumb_file = parts[0] + "-thumb.png"
    vimeo_json_file = parts[0] + "-vimeo.json"

    if not os.path.isfile(video_path):
        show("video file does not exist: " + video_path)
        exit(1)

    if not os.path.isfile(thumb_file):
        show("thumb file does not exist: " + thumb_file)
        exit(1)

    if not os.path.isfile(vimeo_json_file):
        show("vimeo.json file does not exist: " + vimeo_json_file)
        exit(1)

    file = open(vimeo_json_file)

    vimeo_data = json.load(file)
    video_id = vimeo_data['video-id'].encode('ascii')
    title =  video_file
    description = vimeo_data['title'].encode('ascii') + '\n' + vimeo_data['description'].encode('ascii')

    if video_id == "":
        upload_video(
            video_path,
            title,
            description,
            thumb_file
        )
    else:
        replace_video(
            video_id,
            video_path,
            title,
            description,
            thumb_file
        )
