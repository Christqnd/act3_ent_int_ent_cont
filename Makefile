.PHONY: all $(MAKECMDGOALS)

build:
	docker build -t calculator-app .

run:
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest python -B app/calc.py

server:
	docker run --rm --volume `pwd`:/opt/calc --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

interactive:
	docker run -ti --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc  -w /opt/calc calculator-app:latest bash

test-unit:
	docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
	docker cp unit-tests:/opt/calc/results ./
	docker rm unit-tests || true

test-unit-alternative:
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/unit_coverage --junit-xml=results/unit_result.xml -m unit || true	
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/unit_result.xml results/unit_result.html

test-behavior:
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest behave --junit --junit-directory results/  --tags ~@wip test/behavior/
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest bash test/behavior/junit-reports.sh
	
test-api:
	####### Limpieza previa de contenedores y red
	docker stop apiserverapi || true
	docker rm -f apiserverapi || true
	docker network rm calc-test-api || true
	docker network create calc-test-api || true

	####### Levanta backend API Flask en contenedor
	docker run -d --rm -v `pwd`:/opt/calc --network calc-test-api \
		--env PYTHONPATH=/opt/calc --name apiserverapi --env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

	####### Ejecuta tests API con pytest y genera reportes
	docker run --rm -v `pwd`:/opt/calc --network calc-test-api \
		--env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserverapi:5000/ -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/api_coverage.xml --cov-report=html:results/api_coverage --junit-xml=results/api_result.xml -m api || true

	####### Convierte reporte XML de junit a HTML
	docker run --rm -v `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/api_result.xml results/api_result.html

	####### Limpieza final de contenedores y red
	docker stop apiserverapi || true
	docker rm -f apiserverapi || true
	docker network rm calc-test-api || true

test-e2e:
	####### Limpieza previa de red y contenedores
	docker network rm calc-test-e2e || true
	docker network create calc-test-e2e || true
	docker stop apiservere2e || true
	docker rm --force apiservere2e || true
	docker stop calc-web || true
	docker rm --force calc-web || true
	docker stop e2e-tests || true
	docker rm --force e2e-tests || true

	####### Levanta backend sin exponer puerto al host
	docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiservere2e \
		--env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0 --port=5002

	####### Levanta frontend con puerto 80
	docker run -d --network calc-test-e2e --name calc-web -p 80:80 calc-web

	####### Prepara contenedor Cypress para e2e
	docker create --network calc-test-e2e --name e2e-tests cypress/included:4.9.0 --browser chrome || true

	####### Copia archivos Cypress al contenedor
	docker cp ./test/e2e/cypress.json e2e-tests:/cypress.json
	docker cp ./test/e2e/cypress e2e-tests:/cypress

	####### Ejecuta pruebas e2e
	docker start -a e2e-tests || true

	####### Copia resultados al host
	docker cp e2e-tests:/results ./ || true

	####### Limpieza final
	docker rm --force apiservere2e || true
	docker rm --force calc-web || true
	docker rm --force e2e-tests || true
	docker network rm calc-test-e2e || true


test-e2e-wiremock:
	docker network create calc-test-e2e-wiremock || true
	docker stop apiwiremock || true
	docker rm --force apiwiremock || true
	docker stop calc-web || true
	docker rm --force calc-web || true
	docker run -d --rm --name apiwiremock --volume `pwd`/test/wiremock/stubs:/home/wiremock --network calc-test-e2e-wiremock -p 8080:8080 -p 8443:8443 calculator-wiremock
	docker run -d --rm --volume `pwd`/web:/usr/share/nginx/html --volume `pwd`/web/constants.wiremock.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --network calc-test-e2e-wiremock --name calc-web -p 80:80 nginx
	docker run --rm --volume `pwd`/test/e2e/cypress.json:/cypress.json --volume `pwd`/test/e2e/cypress:/cypress --volume `pwd`/results:/results --network calc-test-e2e-wiremock cypress/included:4.9.0 --browser chrome || true
	docker rm --force apiwiremock
	docker rm --force calc-web
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/cypress_result.xml results/cypress_result.html
	docker network rm calc-test-e2e-wiremock

run-web:
	docker run --rm --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.local.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx

stop-web:
	docker stop calc-web

start-sonar-server:
	docker network create calc-sonar || true
	docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 --volume `pwd`/sonar/data:/opt/sonarqube/data --volume `pwd`/sonar/logs:/opt/sonarqube/logs sonarqube:8.3.1-community

stop-sonar-server:
	docker stop sonarqube-server
	docker network rm calc-sonar || true

start-sonar-scanner:
	docker run --rm --network calc-sonar -v `pwd`:/usr/src sonarsource/sonar-scanner-cli

pylint:
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | tee results/pylint_result.txt

build-wiremock:
	docker build -t calculator-wiremock -f test/wiremock/Dockerfile test/wiremock/

start-wiremock:
	docker run -d --rm --name calculator-wiremock --volume `pwd`/test/wiremock/stubs:/home/wiremock -p 8080:8080 -p 8443:8443 calculator-wiremock

stop-wiremock:
	docker stop calculator-wiremock || true

ZAP_API_KEY := my_zap_api_key
ZAP_API_URL := http://zap-node:8080/
ZAP_TARGET_URL := http://calc-web/
zap-scan:
	docker network create calc-test-zap || true
	docker run -d --rm --network calc-test-zap --volume `pwd`:/opt/calc --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --network calc-test-zap --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.test.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx
	docker run -d --rm --network calc-test-zap --name zap-node -u zap -p 8080:8080 -i owasp/zap2docker-stable zap.sh -daemon -host 0.0.0.0 -port 8080 -config api.addrs.addr.name=.* -config api.addrs.addr.regex=true -config api.key=$(ZAP_API_KEY)
	sleep 10
	docker run --rm --volume `pwd`:/opt/calc --network calc-test-zap --env PYTHONPATH=/opt/calc --env ZAP_API_KEY=$(ZAP_API_KEY) --env ZAP_API_URL=$(ZAP_API_URL) --env TARGET_URL=$(ZAP_TARGET_URL) -w /opt/calc calculator-app:latest pytest --junit-xml=results/sec_result.xml -m security  || true
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/sec_result.xml results/sec_result.html
	docker stop apiserver || true
	docker stop calc-web || true
	docker stop zap-node || true
	docker network rm calc-test-zap || true

build-jmeter:
	docker build -t calculator-jmeter -f test/jmeter/Dockerfile test/jmeter

start-jmeter-record:
	docker network create calc-test-jmeter || true
	docker run -d --rm --network calc-test-jmeter --volume `pwd`:/opt/calc --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --network calc-test-jmeter --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.test.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx

stop-jmeter-record:
	docker stop apiserver || true
	docker stop calc-web || true
	docker network rm calc-test-jmeter || true


JMETER_RESULTS_FILE := results/jmeter_results.csv
JMETER_REPORT_FOLDER := results/jmeter/
jmeter-load:
	rm -f $(JMETER_RESULTS_FILE)
	rm -rf $(JMETER_REPORT_FOLDER)
	docker network create calc-test-jmeter || true
	docker run -d --rm --network calc-test-jmeter --volume `pwd`:/opt/calc --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sleep 5
	docker run --rm --network calc-test-jmeter --volume `pwd`:/opt/jmeter -w /opt/jmeter calculator-jmeter jmeter -n -t test/jmeter/jmeter-plan.jmx -l results/jmeter_results.csv -e -o results/jmeter/
	docker stop apiserver || true
	docker network rm calc-test-zap || true