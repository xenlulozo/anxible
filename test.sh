sudo mkdir -p /etc/systemd/system/docker.service.d/
sudo bash -c 'cat <<EOF > /etc/systemd/system/docker.service.d/override.conf
[Unit]
After=home-iCoolSound-SongVideos.mount home-iCoolSound-SongImages.mount home-iCoolSound-SingerImages.mount home-SoundCloud.mount
Requires=home-iCoolSound-SongVideos.mount home-iCoolSound-SongImages.mount home-iCoolSound-SingerImages.mount home-SoundCloud.mount
EOF'