# Docker Local for WPEngine sites

To goal is to get a local containerized version of a production WPEngine site in minutes.

## Getting Started

- Navigate to WPEngine and create a zip file from the utility for backup points. Once the zip is available, download and extract it into a directory with the name of the project you will be working on.

- Clone this repo by specifying a directory as an argument. This will be the directory that will build the containers for each project. Once the repo is cloned, run `./dev-env.sh` `arg` inside it. `arg` is the directory where the zip file was extracted.

### Prerequisites

Docker and docker-compose installed on a Linux, Mac or Windows machine

### Details

- The docker-compose file builds from the latest stable wordpress and mariadb images. Ports mapping can be adjusted.
- Run `docker-compose down` to stop the containers
- Run `docker-compose down --volumes` to stop the containers and remove the database data
- Elasticsearch container is available by default; if not required, comment out the service in `docker-compose.yml`
- To get elasticsearch host, run`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container-name-or-id>` and plug it into the ELASTICPRESSUI
- Optional install of Behat testing suite. The repo has a composer.json file which will install Behat if you run `composer install` in root inside the container
- To initiate the Behat directory scaffolding, run `bin/behat --init` 


