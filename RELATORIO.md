# Relatorio de evidencias - Trabalho Pratico Integrador 01-06

Nome: Pedro Raposo   Data: 24-11-2026
URL do repositorio Git: ____________________________

## E01 - Ambiente (1 valor)
Comandos e versoes observadas:

```
$ docker context ls
default     Current DOCKER_HOST based configuration   unix:///var/run/docker.sock
natixis *   natixis lab (docker-in-docker)            tcp://127.0.0.1:2375

$ docker --version
Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2
$ docker compose version
Docker Compose version v2.24.5
$ git --version
git version 2.43.0
$ docker info
 Context:    natixis
 Server Version: 29.10.0
 Operating System: Alpine Linux v3.24 (containerized)
 OSType: linux / Architecture: x86_64 / Storage Driver: overlay2
```

Componentes do projeto:

| Componente | Ficheiro(s) |
|---|---|
| API | `app.py` (+ `requirements.txt`, `Dockerfile`) |
| Testes | `tests/test_app.py` (+ `requirements-dev.txt`) |
| Compose | `compose.yaml` (+ overlay de incidente `incidente.yaml`) |
| Pipeline | `Jenkinsfile` |

Conclusao: o cliente Docker usa o contexto `natixis` (daemon docker-in-docker) e o daemon
responde (`docker info` devolve a versao do servidor 29.10.0, containers Linux). Compose V2 e Git estao disponiveis.

## E02 - Dockerfile e container (3 valores)
Tag da imagem; docker ps; HTTP /health; utilizador efetivo do container:

Nota de ambiente (porta alternativa): o daemon e um DinD (`natixis-lab`) que so expoe ao host as
portas 8100-8199 (`<IP_HOST>:8100-8199 -> 8100-8199`) e a 8100 ja esta ocupada. Usou-se
**host 8180 -> container 8000** (destino interno 8000 inalterado). Dentro do DinD a porta e publicada
sem `127.0.0.1:` porque o trafego chega pela interface de rede do DinD, nao pelo loopback.

```
$ docker build -t natixis-support:1.0 .
 => naming to docker.io/library/natixis-support:1.0      (ID d5ae952a8b50, 143MB)
$ docker run -d --name tp-api -p 8180:8000 natixis-support:1.0
$ docker ps
IMAGE                 STATUS        PORTS                     NAMES
natixis-support:1.0   Up 7 seconds  0.0.0.0:8180->8000/tcp    tp-api
$ curl -i http://<IP_HOST>:8180/health
HTTP/1.1 200 OK
{"status":"ok","service":"support-api","version":"1.0"}
$ docker logs --tail 15 tp-api
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     <IP_HOST>:37610 - "GET /health HTTP/1.1" 200 OK
$ docker exec tp-api id
uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
$ docker exec tp-api ls -ld /data      -> drwxr-xr-x appuser appuser /data (escrita OK)
$ docker exec tp-api ls /app           -> app.py requirements.txt (sem .git, testes, pdf, caches)
$ docker rm -f tp-api
```

Conclusao: a imagem `natixis-support:1.0` constroi com dependencias em camada propria (cache) e corre como
`appuser` (uid 10001, nao root) com escrita em `/data`. O `/health` responde HTTP 200 com `status="ok"` e o
`.dockerignore` mantem fora da imagem o repositorio Git, ambientes virtuais, caches, `.env`, logs e evidencias.

## E03 - Compose, DNS, healthcheck e volume (4 valores)
Resultado de docker compose config; health; teste checker -> api; contador antes/depois da recriacao:

## E04 - Incidente Docker (3 valores)
Sintoma, comandos de investigacao, causa-raiz, alteracao realizada, prova da recuperacao e contador preservado:

## E05 - Git (3 valores)
Branch, hashes de commits, merge e tag v1.0.0:

## E06 - Jenkins SUCCESS (4 valores)
URL/numero do build, etapas e identificador da imagem construida:

## E07 - Jenkins FAILURE e recuperacao (2 valores)
Build FAILURE, etapa que falhou e excerto relevante do log; build SUCCESS apos correcao:

## Verificacao final
[ ] Dockerfile [ ] compose.yaml [ ] app.py [ ] tests/ [ ] Jenkinsfile
[ ] Historico Git [ ] Tag v1.0.0 [ ] Evidencias E01-E07
