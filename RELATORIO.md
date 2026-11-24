# Relatorio de evidencias - Trabalho Pratico Integrador 01-06

Nome: Pedro Raposo   Data: 24-11-2026
URL do repositorio Git: https://github.com/PedroRaposo02/tp-devops-integrador

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
#11 naming to docker.io/library/natixis-support:1.0 0.1s done
$ docker image ls natixis-support:1.0
natixis-support:1.0   d5ae952a8b50   143MB
$ docker run -d --name tp-api -p 8180:8000 natixis-support:1.0
$ docker ps          (colunas resumidas)
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
$ docker exec tp-api ls -ld /data
drwxr-xr-x 2 appuser appuser 4096 Nov 24 09:48 /data
$ docker exec tp-api ls /app
app.py
requirements.txt
$ docker rm -f tp-api
```

O `/data` pertence ao `appuser` (foi testada a escrita com `touch`) e em `/app` so existem `app.py` e
`requirements.txt`, sem `.git`, testes nem caches.

Conclusao: a imagem `natixis-support:1.0` constroi com dependencias em camada propria (cache) e corre como
`appuser` (uid 10001, nao root) com escrita em `/data`. O `/health` responde HTTP 200 com `status="ok"` e o
`.dockerignore` mantem fora da imagem o repositorio Git, ambientes virtuais, caches, `.env`, logs e evidencias.

## E03 - Compose, DNS, healthcheck e volume (4 valores)
Resultado de docker compose config; health; teste checker -> api; contador antes/depois da recriacao:

Porta alternativa: host 8180 -> container 8000 (mesma razao do E02).

Excerto do `compose.yaml`:
```yaml
  api:
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
  checker:
    depends_on:
      api:
        condition: service_healthy
```

```
$ docker compose config --quiet
(sem output, exit 0 -> configuracao valida)

$ docker compose up -d --build
$ docker compose ps          (colunas resumidas)
NAME                       IMAGE                   STATUS                   PORTS
natixis-integrador-api-1   natixis-support:local   Up 7 seconds (healthy)   0.0.0.0:8180->8000/tcp

$ docker compose --profile diagnostico run --rm checker -fsS http://api:8000/health
 Container natixis-integrador-api-1  Running
{"status":"ok","service":"support-api-integrador","version":"1.0"}

$ curl http://<IP_HOST>:8180/visits              -> {"visits":0}
$ curl -X POST http://<IP_HOST>:8180/visits      -> {"visits":1}
$ curl http://<IP_HOST>:8180/visits              -> {"visits":1}

$ docker compose up -d --force-recreate            (container ceb30ea6d10d -> 8d96708cf382)
$ docker compose ps          (colunas resumidas)
natixis-integrador-api-1   natixis-support:local   Up 6 seconds (healthy)   0.0.0.0:8180->8000/tcp
$ curl http://<IP_HOST>:8180/visits              -> {"visits":1}
```

Conclusao: o healthcheck usa Python/urllib contra `http://127.0.0.1:8000/health` (sem instalar curl) e o
servico fica `healthy`. O `checker` so arranca depois de `api` estar `service_healthy` e resolve o nome
`api` pelo DNS interno da rede do Compose. **O contador nao se perdeu porque `visitas.txt` esta no volume
nomeado `app-data` (montado em `/data`), que existe independentemente do container e e reutilizado
quando este e recriado.**

## E04 - Incidente Docker (3 valores)
Sintoma, comandos de investigacao, causa-raiz, alteracao realizada, prova da recuperacao e contador preservado:

Contador antes do incidente: `curl http://<IP_HOST>:8180/visits` -> `{"visits":1}`

**1. Sintoma**
```
$ docker compose -f compose.yaml -f incidente.yaml up -d --force-recreate
 Container natixis-integrador-api-1  Recreated
 Container natixis-integrador-api-1  Started

$ docker compose -f compose.yaml -f incidente.yaml ps          (colunas resumidas)
NAME                       IMAGE                   STATUS                      PORTS
natixis-integrador-api-1   natixis-support:local   Up 35 seconds (unhealthy)   0.0.0.0:8180->8000/tcp
```
O container esta a correr mas fica `unhealthy`: o healthcheck nao consegue obter resposta da API.

**2. Comandos de diagnostico**
```
$ docker compose -f compose.yaml -f incidente.yaml logs --tail 30 api
api-1  | INFO:     Application startup complete.
api-1  | INFO:     Uvicorn running on http://0.0.0.0:8001 (Press CTRL+C to quit)

$ docker compose -f compose.yaml -f incidente.yaml config      (excerto do servico api)
    command: [python, -m, uvicorn, app:app, --host, 0.0.0.0, --port, "8001"]
    healthcheck:
      test: [CMD, python, -c, "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"]
    ports:
      - target: 8000
        published: "8180"
```

**3. Causa**
O `incidente.yaml` substitui o `command` do servico `api` e o uvicorn passa a escutar na porta **8001** (confirmado
nos logs). O mapeamento de portas (`8180 -> 8000`) e o healthcheck (`127.0.0.1:8000/health`) continuam a usar a porta
**8000**, onde nao ha nenhum processo a escutar. Por isso o healthcheck falha (`unhealthy`) e o acesso pela 8180 nao chega a API.

**4. Correcao**
Regressar a configuracao base (sem o overlay `incidente.yaml`, que fica no repositorio sem alteracoes) e recriar o
servico, sem remover o volume. So o `api` e recriado, porque o `checker` pertence ao profile `diagnostico` e nao
esta ativo:
```
$ docker compose up -d --force-recreate
 Container natixis-integrador-api-1  Recreated
 Container natixis-integrador-api-1  Started
```

**5. Validacao**
```
$ docker compose ps          (colunas resumidas)
NAME                       IMAGE                   STATUS                   PORTS
natixis-integrador-api-1   natixis-support:local   Up 7 seconds (healthy)   0.0.0.0:8180->8000/tcp

$ curl http://<IP_HOST>:8180/health
{"status":"ok","service":"support-api-integrador","version":"1.0"}

$ curl http://<IP_HOST>:8180/visits
{"visits":1}
```
O servico voltou a `healthy`, o `/health` responde com `status="ok"` e o contador manteve o valor de antes do
incidente (`1`), porque o volume nomeado `app-data` nunca foi removido.

## E05 - Git (3 valores)
Branch, hashes de commits, merge e tag v1.0.0:

Repositorio ja inicializado (branch `main`), por isso nao foi necessario `git init`. A aplicacao funcional ja
estava versionada nos commits dos exercicios anteriores, por isso o commit `feat: ambiente integrador funcional`
so acrescenta ao relatorio a verificacao do `.gitignore` e marca o estado base antes da branch de correcao.

```
$ git check-ignore -v .venv/x .env __pycache__/x.pyc .pytest_cache/x teste.log
.gitignore:1:.venv/          .venv/x
.gitignore:5:.env            .env
.gitignore:2:__pycache__/    __pycache__/x.pyc
.gitignore:3:.pytest_cache/  .pytest_cache/x
.gitignore:6:*.log           teste.log
```

Branch de correcao: `fix/health-info` (acrescenta `"team": "support"` ao `/health` e a assercao em `test_health`).

```
$ git commit -m "feat: ambiente integrador funcional"
[main f6bbdcb] feat: ambiente integrador funcional
$ git switch -c fix/health-info
$ .venv/bin/python -m pytest -q
2 passed, 1 warning in 1.85s
$ git commit -m "fix: acrescentar identificacao no health"
[fix/health-info db29972] fix: acrescentar identificacao no health
$ git switch main
$ git merge fix/health-info
Updating f6bbdcb..db29972
Fast-forward
$ git tag -a v1.0.0 -m "Release integrador 1.0.0"
$ git log --oneline --graph --decorate -6
* db29972 (HEAD -> main, tag: v1.0.0, fix/health-info) fix: acrescentar identificacao no health
* f6bbdcb feat: ambiente integrador funcional
* 8b549f7 (origin/main) Exercicio 03
* 08aae77 Exercicio 03
* b2b4c5e Exercicio 02
* 14a9cab Exercicio 01
$ git push -u origin main
   8b549f7..db29972  main -> main
$ git push origin v1.0.0
 * [new tag]         v1.0.0 -> v1.0.0
```

| Item | Valor |
|---|---|
| Commit base funcional | `f6bbdcb` feat: ambiente integrador funcional |
| Commit da correcao | `db29972` fix: acrescentar identificacao no health |
| Merge | `fix/health-info` -> `main` (fast-forward, `main` aponta para `db29972`) |
| Tag anotada | `v1.0.0` -> `db29972` ("Release integrador 1.0.0") |
| Remoto | https://github.com/PedroRaposo02/tp-devops-integrador |

Conclusao: a correcao foi desenvolvida numa branch propria, testada (2 testes a passar, incluindo a nova assercao
`team == "support"`) e integrada em `main`. Como `main` nao tinha commits novos desde a criacao da branch, o Git
fez um merge fast-forward. A release fica identificada pela tag anotada `v1.0.0`, publicada no remoto com o historico.

## E06 - Jenkins SUCCESS (4 valores)
URL/numero do build, etapas e identificador da imagem construida:

**Ambiente Jenkins** (pasta `jenkins/`, contexto `natixis`, compose separado do da aplicacao para que os
`docker compose up --force-recreate` dos E03/E04 nao recriem o CI):

| Ficheiro | Funcao |
|---|---|
| `jenkins/compose.yaml` | Servico `jenkins` (imagem oficial `jenkins/jenkins:lts-jdk21`, porta 8190 -> 8080, volume `jenkins_home` com jobs e historico) e servico `ci-agent` (agente inbound por WebSocket, socket do daemon montado e grupo 2375 = dono do socket). |
| `jenkins/Dockerfile.agent` | `jenkins/inbound-agent:jdk21` + Git, Python 3/venv e Docker CLI, exigidos pelo Jenkinsfile. |
| `jenkins/.env` (fora do Git) | `JENKINS_AGENT_SECRET` (segredo do no) e password do admin. |

Configuracao inicial (passos do assistente, feitos pela API/CLI do Jenkins): desbloqueio com a password inicial,
instalacao dos plugins `workflow-aggregator` (Pipeline), `git` e `pipeline-stage-view`, criacao do admin, no
permanente **`ci-python-docker`** (label `ci-python-docker`, `/home/jenkins/agent`, ligacao inbound por WebSocket)
e job **`tp-devops-integrador`** do tipo **Pipeline from SCM** (Git
`https://github.com/PedroRaposo02/tp-devops-integrador.git`, branch `*/main`, script `Jenkinsfile`).

```
$ docker exec natixis-integrador-ci-ci-agent-1 sh -c 'id; python3 --version; docker version ...'
uid=1000(jenkins) gid=1000(jenkins) groups=1000(jenkins),2375
Python 3.13.5
docker CLI 26.1.5+dfsg1 -> daemon 29.10.0
```

**Jenkinsfile**: pipeline declarativa no agente `ci-python-docker`, timeout de 15 min, sem builds concorrentes:
- `Checkout`: `checkout scm` clona o repositorio definido no job e faz `git checkout -f` do commit exato da
  `main` (rastreabilidade build <-> commit).
- `Tests`: `python3 -m venv .venv`, `pip install -r requirements.txt -r requirements-dev.txt`, `pytest -q`.
- `Docker Build`: `docker build -t "natixis-support:ci-${BUILD_NUMBER}" .` e
  `docker image inspect ... --format '{{.Id}}'`.

| Item | Valor |
|---|---|
| Build | **#2**, `http://<IP_HOST>:8190/job/tp-devops-integrador/2/` |
| Resultado | **SUCCESS** (20s) |
| Etapas | Checkout SUCCESS, Tests SUCCESS, Docker Build SUCCESS |
| Commit | `5815e3e` |
| Imagem | `natixis-support:ci-2` |
| ID da imagem | `sha256:c7a7192ce697acea6eecfcd2eead12c4d1ddf38665d425dbb89081f3dd70434a` |

Excerto do Console Output:
```
Started tp-devops-integrador #2
Obtained Jenkinsfile from git https://github.com/PedroRaposo02/tp-devops-integrador.git
Running on ci-python-docker in /home/jenkins/agent/workspace/tp-devops-integrador
Checking out Revision 5815e3ecbe27922537a44ae590ffa9b1b59cbb13 (refs/remotes/origin/main)
+ python3 -m venv .venv
+ .venv/bin/python -m pip install -r requirements.txt -r requirements-dev.txt
+ .venv/bin/python -m pytest -q
2 passed, 1 warning in 0.38s
+ docker build -t natixis-support:ci-2 .
#11 naming to docker.io/library/natixis-support:ci-2 0.1s done
+ docker image inspect natixis-support:ci-2 --format {{.Id}}
sha256:c7a7192ce697acea6eecfcd2eead12c4d1ddf38665d425dbb89081f3dd70434a
Finished: SUCCESS
```

Conclusao: o Jenkins obteve o `Jenkinsfile` e o codigo a partir do Git (commit `5815e3e`), executou os testes num
ambiente virtual isolado no agente `ci-python-docker` e construiu a imagem com uma tag unica por execucao
(`ci-${BUILD_NUMBER}`), confirmada com `docker image inspect`. As tres etapas terminaram em SUCCESS.
O build #1 correu sobre um commit entretanto reorganizado no historico (squash dos commits do Exercicio 05); o #2
corresponde ao commit atual.

## E07 - Jenkins FAILURE e recuperacao (2 valores)
Build FAILURE, etapa que falhou e excerto relevante do log; build SUCCESS apos correcao:

**Falha controlada:** em `tests/test_app.py` a assercao passou temporariamente a esperar `status == "offline"`
(a API continua a devolver `"ok"`). Commit `d1d9c2d`, push e novo build.

| Item | Valor |
|---|---|
| Build | **#3**, `http://<IP_HOST>:8190/job/tp-devops-integrador/3/` |
| Commit | `d1d9c2d` (assercao `"offline"`) |
| Resultado | **FAILURE** |
| Etapas | Checkout SUCCESS, **Tests FAILED**, Docker Build nao executado |

```
Checking out Revision d1d9c2dda6a42757ab1b3e89f026b978d4460226 (refs/remotes/origin/main)
+ .venv/bin/python -m pytest -q
F.                                                                       [100%]
>       assert response.json()["status"] == "offline"
E       AssertionError: assert 'ok' == 'offline'
tests/test_app.py:9: AssertionError
FAILED tests/test_app.py::test_health - AssertionError: assert 'ok' == 'offline'
1 failed, 1 passed, 1 warning in 0.42s
[Pipeline] { (Docker Build)
Stage "Docker Build" skipped due to earlier failure(s)
ERROR: script returned exit code 1
Finished: FAILURE
```
Interpretacao: o `pytest` terminou com exit code 1 porque `test_health` esperava `"offline"` e a API devolveu
`"ok"`. O passo `sh` falhou, a etapa Tests ficou FAILED e o Jenkins saltou o Docker Build. Nao foi construida
nenhuma imagem `natixis-support:ci-3`: uma alteracao que parte os testes nunca chega a gerar artefacto.

**Recuperacao:** repor a assercao `status == "ok"`, commit `8ab977a`, push e novo build.

| Item | Valor |
|---|---|
| Build | **#4**, `http://<IP_HOST>:8190/job/tp-devops-integrador/4/` |
| Commit | `8ab977a` (assercao reposta) |
| Resultado | **SUCCESS** |
| Etapas | Checkout SUCCESS, Tests SUCCESS, Docker Build SUCCESS |
| Imagem | `natixis-support:ci-4` (`sha256:c7a7192ce697acea6eecfcd2eead12c4d1ddf38665d425dbb89081f3dd70434a`) |

```
Checking out Revision 8ab977a11296200a1f32e7790e64b4048420091a (refs/remotes/origin/main)
2 passed, 1 warning in 0.34s
+ docker build -t natixis-support:ci-4 .
#11 naming to docker.io/library/natixis-support:ci-4 0.2s done
+ docker image inspect natixis-support:ci-4 --format {{.Id}}
sha256:c7a7192ce697acea6eecfcd2eead12c4d1ddf38665d425dbb89081f3dd70434a
Finished: SUCCESS
```

Historico de builds do job (nao eliminado): #1 SUCCESS, #2 SUCCESS, **#3 FAILURE**, **#4 SUCCESS**.
Os commits da falha (`d1d9c2d`) e da correcao (`8ab977a`) ficam no historico Git.

Conclusao: a pipeline bloqueou a alteracao defeituosa na etapa Tests, antes da construcao da imagem. Repor a
assercao correta devolveu o SUCCESS nas tres etapas, e cada build fica associado ao commit exato que testou.

## Verificacao final
[x] Dockerfile [x] compose.yaml [x] app.py [x] tests/ [x] Jenkinsfile
[x] Historico Git [x] Tag v1.0.0 [x] Evidencias E01-E07
