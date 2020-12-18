# MariaDB-ES-Docker

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


