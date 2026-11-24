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
