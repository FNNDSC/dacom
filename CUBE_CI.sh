#!/bin/bash
set -ev
cd ..
git clone https://github.com/FNNDSC/ChRIS_ultron_backEnd.git
cd pfcon/
docker build -t fnndsc/pfcon:latest .
cd ../ChRIS_ultron_backEnd/
docker-compose up -d
docker-compose exec chris_dev_db sh -c 'while ! mysqladmin -uroot -prootp status 2> /dev/null; do sleep 5; done;'
docker-compose exec chris_dev_db mysql -uroot -prootp -e 'GRANT ALL PRIVILEGES ON *.* TO "chris"@"%"'
docker-compose exec chris_dev python manage.py migrate