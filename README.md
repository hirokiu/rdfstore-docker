# rdfstore-docker
virtuoso container with docker-compose

## prepare
- change admin password
- container start
`docker-compose up -d`

## 
- 全コンテナ停止: `docker stop $(docker ps -q)`
- 全コンテナ削除: `docker rm $(docker ps -q -a)`
- 全イメージ削除: `docker rmi $(docker images -q)`