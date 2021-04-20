# MariaDB-ES-Docker

This is the Git repo of the Docker image for MariaDB Enterprise. This is not the [Docker "Official Image"](https://github.com/docker-library/official-images#what-are-official-images) for [MariaDB](https://hub.docker.com/_/mariadb/), which is based on the community version of MariaDB.

## Getting Help
If you need general help with MariaDB on Docker, the [Docker and MariaDB](https://mariadb.com/kb/en/docker-and-mariadb/) section of the MariaDB Knowledge Base contains lots of useful info. The Knowledge Base also has a page where you can [Ask a Question](https://mariadb.com/kb/en/docker-and-mariadb/ask). Also see the [Getting Help with MariaDB](https://mariadb.com/kb/en/getting-help-with-mariadb/) article.

On StackExchange, questions tagged with 'mariadb' and 'docker' on the Database Administrators (DBA) StackExchange can be found [here](https://dba.stackexchange.com/questions/tagged/docker+mariadb).

If you run into any bugs or have ideas on new features you can file bug reports and feature requests on the [MariaDB JIRA](https://jira.mariadb.org). File them under the "MDEV" project and "Docker" component and in your description be sure to specify that you are referencing the MariaDB Enterprise Server (ES) Docker images to make sure it goes to the correct people.

## Parameters

| Variable | Default| Allowed values |
| --- | --- | --- |
| MARIADB_ROOT_PASSWORD | RANDOM | valid password, RANDOM, EMPTY |
| MARIADB_DATABASE | No Default | Valid DB name |
| MARIADB_USER | No Default | Valid username |
| MARIADB_PASSWORD | No Default | Valid password |
| MARIADB_ROOT_HOST | '%' | Valid hostname |
| MARIADB_INITDB_TZINFO | 1 | 0, 1 |
| JEMALLOC | 0 | 0, 1 |
| IMAGEDEBUG | 0 | 0, 1 |


## Compatibility parameters

| Variable | Default| Allowed values |
| --- | --- | --- |
| MARIADB_ALLOW_EMPTY_PASSWORD | 0 |0, 1 |
| MARIADB_RANDOM_ROOT_PASSWORD | Yes | Ignored |
| MARIADB_INITDB_SKIP_TZINFO | 0 |0, 1 |

