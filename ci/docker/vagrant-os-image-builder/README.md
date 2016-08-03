# Building new docker image

```
vagrant up
vagrant ssh
```

On vagrant VM:

```
cd /opt/bosh
docker login ...
sudo ./build_docker_image.sh
```