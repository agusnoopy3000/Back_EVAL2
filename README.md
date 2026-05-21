# Back_EVAL2 — Backend Express + MySQL

Backend del proyecto **Innovatech Chile (EP2 — ISY1101 DuocUC)**. API REST en Node.js/Express con persistencia en MySQL, contenedorizado con Docker y desplegado automáticamente en AWS EC2 vía GitHub Actions.

- **Repositorio Backend:** https://github.com/agusnoopy3000/Back_EVAL2
- **Repositorio Frontend:** https://github.com/agusnoopy3000/Front_Eval2
- **Repositorio Data (scripts SQL):** https://github.com/agusnoopy3000/Data_Eval2
- **Imagen Docker Hub:** https://hub.docker.com/r/agusnoopy/back-eval2

---

## 📦 Stack técnico

| Capa | Tecnología | Versión |
|---|---|---|
| Runtime | Node.js | 20 (alpine) |
| Framework | Express | 4.18 |
| Driver BD | mysql2 | 3.6 |
| Base de datos | MySQL | 8.0 |
| Contenedorización | Docker + Compose v2 | 25.0 / v2.29 |
| CI/CD | GitHub Actions (self-hosted runner en EC2) | — |
| Registry | Docker Hub público | — |
| Host | AWS EC2 Amazon Linux 2023 (t2.micro) | — |

---

## 🗂️ Estructura del repositorio

```
Back_EVAL2/
├── .github/workflows/deploy.yml   # Pipeline CI/CD
├── initdb/                        # Scripts SQL inicializadores (montados en MySQL)
│   ├── 01_creacion_base_datos.sql
│   └── 02_backup_y_mantenimiento.sql
├── .dockerignore                  # Excluye node_modules, .env, .git del build
├── .env.example                   # Plantilla de variables (sin credenciales)
├── .gitignore
├── Dockerfile                     # Multi-stage: builder + runtime no-root
├── docker-compose.yml             # Stack: MySQL + backend
├── package.json
├── server.js                      # Entrypoint Express
└── README.md
```

---

## 🐳 Contenedorización (IE1)

### Dockerfile multi-stage

```dockerfile
# Stage 1: builder — instala dependencias de producción
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

# Stage 2: runtime — imagen final mínima, usuario no-root
FROM node:20-alpine AS runtime
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=app:app . .
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/ || exit 1
CMD ["node", "server.js"]
```

**Buenas prácticas aplicadas:**
- ✅ **Multi-stage build** → la imagen final no incluye npm cache ni archivos del builder.
- ✅ **Imagen base alpine** → ~150MB vs ~900MB de la imagen Debian completa.
- ✅ **Usuario no-root** (`app`) → mitigación de impacto si el contenedor es comprometido.
- ✅ **`.dockerignore`** → excluye `node_modules`, `.env`, `.git` del contexto de build.
- ✅ **HEALTHCHECK** → Docker monitorea automáticamente que la API responda.
- ✅ **`npm cache clean`** → reduce tamaño final.

### docker-compose.yml — stack completo

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: eval2-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
    volumes:
      - mysql_data:/var/lib/mysql              # named volume (persistencia)
      - ./initdb:/docker-entrypoint-initdb.d:ro # bind mount RO (init scripts)
    networks: [backend-net]
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p${DB_PASSWORD}"]
      interval: 10s
      retries: 10

  backend:
    image: ${DOCKERHUB_USERNAME}/back-eval2:latest
    container_name: eval2-back
    depends_on:
      mysql: { condition: service_healthy }   # arranca solo cuando MySQL responde
    environment:
      PORT: 3000
      DB_HOST: mysql                          # nombre del servicio en la red interna
      DB_USER: root
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
    ports: ["3000:3000"]
    networks: [backend-net]

volumes:
  mysql_data:
    driver: local

networks:
  backend-net:
    driver: bridge
```

**Decisiones clave:**
- Red interna `backend-net` (bridge) → el backend resuelve `mysql` por DNS interno, sin exponer el puerto 3306 al host.
- `depends_on` con `condition: service_healthy` → evita race condition en el primer arranque.
- Variables sensibles inyectadas vía `.env` (no commiteado).

---

## 💾 Persistencia de datos (IE2)

Se usa **named volume** `mysql_data` montado en `/var/lib/mysql`.

### ¿Por qué named volume y no bind mount?

| Criterio | Named volume (✅ elegido) | Bind mount |
|---|---|---|
| Portabilidad | Docker gestiona la ruta interna | Depende de path absoluto del host |
| Permisos | Docker maneja UID/GID | Hay que ajustar manualmente |
| Backup | `docker run --rm -v mysql_data:/data ...` | `tar` del directorio host |
| Sobrevive `docker compose down` | ✅ Sí | ✅ Sí |
| Sobrevive `docker compose down -v` | ❌ No (intencional) | ❌ No |
| Caso de uso ideal | Datos de aplicación (BD, uploads) | Código fuente en dev |

Para los scripts SQL de inicialización (`initdb/`) sí usamos **bind mount read-only**, porque queremos versionarlos en el repo y que sean inmutables desde el contenedor.

### Continuidad operativa demostrada

```bash
docker compose down                 # Detiene y elimina contenedores
docker volume ls                    # mysql_data sigue existiendo
docker compose up -d                # Recrea contenedores
# → Los datos siguen ahí, MySQL no re-ejecuta los scripts initdb
```

---

## 🚀 CI/CD GitHub Actions (IE3 + IE7)

### Flujo del pipeline (`.github/workflows/deploy.yml`)

```
push a rama "deploy"
       ↓
[1] Checkout código (actions/checkout@v4)
       ↓
[2] Login Docker Hub (docker login --password-stdin)
       ↓
[3] Build imagen (docker build con tags :latest y :SHA)
       ↓
[4] Push a Docker Hub (agusnoopy/back-eval2:latest + :SHA)
       ↓
[5] Deploy local (runner está en la misma EC2-back):
    - Copia docker-compose.yml e initdb/ a ~/app/
    - docker compose pull backend
    - docker compose up -d
    - docker image prune (limpieza)
       ↓
✅ API actualizada en http://54.196.196.118:3000 (acceso restringido por SG)
```

### Trigger: rama `deploy`

```yaml
on:
  push:
    branches: [deploy]
  workflow_dispatch:   # también permite trigger manual
```

Esto permite **trabajar libremente en `main` o feature branches sin desplegar**. Solo cuando se hace merge / push a `deploy`, se dispara CI/CD.

### Self-hosted runner

El workflow corre sobre un **GitHub Actions self-hosted runner** instalado en la propia EC2-back como systemd service. Ventajas:

- ✅ Sin cuotas de minutos.
- ✅ Cache de capas Docker entre runs (build más rápido).
- ✅ Deploy local sin necesidad de SSH externo.

Cambiar a runners hosted requiere 1 línea: `runs-on: [self-hosted, back]` → `runs-on: ubuntu-latest`.

### GitHub Secrets utilizados

| Secret | Uso |
|---|---|
| `DOCKERHUB_USERNAME` | Login al registry |
| `DOCKERHUB_TOKEN` | Personal Access Token (Read & Write) — nunca password |
| `EC2_HOST` | IP pública (referencia; deploy actual es local) |
| `EC2_USER` | `ec2-user` |
| `EC2_SSH_KEY` | Contenido completo del .pem (referencia) |

Todos los secrets cifrados por GitHub, nunca aparecen en logs, se inyectan al workflow solo en ejecución.

### ¿Por qué Docker Hub y no ECR?

| Criterio | Docker Hub (✅) | AWS ECR |
|---|---|---|
| Costo | Gratis para repos públicos | Gratis 500MB/mes |
| Setup | Token + 1 secret | IAM role + AWS CLI + rotación |
| AWS Academy Learner Lab | Compatible | Requiere permisos IAM restringidos |

Para producción real recomendaríamos ECR (mejor integración con ECS/EKS). Para el alcance del Lab, Docker Hub es la elección correcta.

---

## 🌐 Arquitectura en AWS (IE6)

```
                       Internet
                          │
                          │ HTTP :80
                          ▼
              ┌───────────────────────┐
              │  EC2 eval2-front      │   SG-Frontend
              │  184.73.24.77 (pública)│   Inbound: 22, 80
              │  Container: eval2-front│
              └────────────┬───────────┘
                           │ HTTP :3000 (red privada AWS)
                           │ via IP 172.31.31.128
                           ▼
              ┌───────────────────────┐
              │  EC2 eval2-back       │   SG-Backend
              │  54.196.196.118       │   Inbound: 22 desde 0.0.0.0/0
              │                       │              3000 desde SG-Frontend
              │  Containers:          │              (NO desde Internet)
              │  - eval2-back         │
              │  - eval2-mysql        │
              │  Volume: mysql_data   │
              └───────────────────────┘
```

**Solo el frontend es accesible desde Internet.** El backend solo acepta tráfico en el puerto 3000 desde instancias dentro del SG-Frontend (configurado por Source = sg-id del front, no por IP). Esto cumple el requisito de "acceso restringido desde subred privada según configuración" del IE7.

---

## 🛠️ Uso local

```bash
git clone https://github.com/agusnoopy3000/Back_EVAL2.git
cd Back_EVAL2

cp .env.example .env
# Edita .env con DOCKERHUB_USERNAME, DB_PASSWORD, DB_NAME

docker build -t agusnoopy/back-eval2:latest .
docker compose up -d
docker compose logs -f backend

# Verificar
curl http://localhost:3000/
```

### Endpoints

| Método | Path | Descripción |
|---|---|---|
| GET | `/` | Health check + timestamp |
| GET | `/api/usuarios` | Lista todos los usuarios |
| GET | `/api/usuarios/:id` | Obtiene un usuario |
| POST | `/api/usuarios` | Crea un usuario |
| PUT | `/api/usuarios/:id` | Actualiza un usuario |
| DELETE | `/api/usuarios/:id` | Elimina un usuario |

---

## 🧪 Probar el ciclo CI/CD

```bash
git checkout deploy
# Hacer cualquier cambio
git commit -am "test: cambio de prueba"
git push origin deploy
# Ver el run en https://github.com/agusnoopy3000/Back_EVAL2/actions
```

El cambio queda desplegado en EC2 en ~15 segundos.

---

## 📚 Asignatura

ISY1101 Introducción a Herramientas DevOps — DuocUC. EP2 Innovatech Chile (etapa 2).
