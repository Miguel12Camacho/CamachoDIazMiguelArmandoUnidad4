

## Arquitectura

```
Navegador ──HTTPS──▶ nginx (balanceador, 80/443)
                       ├──▶ app-1 (Node.js + Express) ──┐
                       ├──▶ app-2 (Node.js + Express) ──┼──▶ PostgreSQL (db)
                       └──▶ app-3 (Node.js + Express) ──┘
```

- Las tres instancias de la aplicación son idénticas y no guardan estado propio.
- Las sesiones de usuario se almacenan en PostgreSQL (tabla `user_sessions`), por eso una persona puede ser atendida por una instancia distinta en cada petición sin perder su sesión.
- nginx reparte el tráfico con el algoritmo `least_conn` (menos conexiones activas) y retira temporalmente una instancia si falla tres veces seguidas.

## 1. Servidor de aplicaciones

La aplicación es Node.js + Express. El `Dockerfile` la empaqueta con `node:20-alpine`, instala solo dependencias de producción, corre con un usuario sin privilegios y define un `HEALTHCHECK`.

El endpoint `GET /api/health` informa: estado general, instancia que respondió, tiempo activo, versión de Node.js, entorno, estado y latencia de la base de datos, dominio, si la conexión es segura y la URL del repositorio. Devuelve `503` si la base de datos no responde, para que un balanceador pueda retirar la instancia.

Cada respuesta incluye la cabecera `X-Served-By` con el nombre de la instancia. El servidor también se cierra de forma ordenada al recibir `SIGTERM`.

## 2. Servidor de base de datos

El servicio `db` usa `postgres:16-alpine`, guarda los datos en el volumen `db-data` y ejecuta `sql/schema.sql` automáticamente la primera vez que se crea. Las aplicaciones esperan a que la base esté lista (`healthcheck` con `pg_isready`) antes de iniciar.

Para entrar a la base desde la terminal:

```bash
docker compose exec db psql -U postgres -d tienda_digital
```

## 3. Balanceo de cargas

Archivo: `nginx/default.conf.template`.

```nginx
upstream tienda_app {
    least_conn;
    server app1:3000 max_fails=3 fail_timeout=15s;
    server app2:3000 max_fails=3 fail_timeout=15s;
    server app3:3000 max_fails=3 fail_timeout=15s;
}
```

Para demostrarlo:

1. Abre la página y entra a la sección "Estado del sistema".
2. Presiona "Probar balanceo (12 peticiones)". Aparecen barras con las peticiones atendidas por `app-1`, `app-2` y `app-3`.
3. Desde la terminal:

```bash
for i in 1 2 3 4 5 6; do curl -sk -I https://localhost/api/health | grep -i x-served-by; done
```

Para probar la tolerancia a fallos, detén una instancia (`docker compose stop app2`) y repite la prueba: el sitio sigue funcionando con las otras dos.

## 4. Configuración de dominio

El dominio se define con la variable `DOMAIN` del archivo `.env`. nginx la usa en `server_name` y el certificado se emite para ese nombre.

Pasos con un dominio real:

1. Obtén un servidor con IP pública (por ejemplo una máquina virtual) con Docker instalado.
2. En el panel de tu proveedor de dominio crea un registro DNS tipo **A** que apunte `tu-dominio.com` a la IP del servidor (y opcionalmente `www` como **CNAME**).
3. Espera a que el DNS se propague. Compruébalo con `nslookup tu-dominio.com`.
4. Escribe `DOMAIN=tu-dominio.com` y `APP_URL=https://tu-dominio.com` en `.env`.

Si publicas en Render u otro servicio similar, el dominio personalizado se configura desde su panel (Settings → Custom Domains) y el servicio emite el certificado automáticamente.

## 5. Certificados de seguridad

nginx atiende HTTPS en el puerto 443 con TLS 1.2 y 1.3, redirige todo el tráfico HTTP (puerto 80) a HTTPS y envía la cabecera `Strict-Transport-Security` (HSTS). Las cookies de sesión se marcan como `Secure` y `HttpOnly`.

Nginx busca los certificados en `certs/fullchain.pem` y `certs/privkey.pem`. Hay dos formas de generarlos:

**Para pruebas locales (certificado autofirmado):**

```bash
./scripts/generar-certificado.sh localhost
```

El navegador mostrará una advertencia porque el certificado no está emitido por una autoridad reconocida. Es normal en pruebas locales.

**Para un dominio real (Let's Encrypt, gratuito y reconocido por los navegadores):**

```bash
./scripts/certificado-letsencrypt.sh tu-dominio.com tu-correo@ejemplo.com
```

El script detiene brevemente el balanceador, solicita el certificado con Certbot, lo copia a `certs/` y vuelve a iniciar nginx. Los certificados de Let's Encrypt duran 90 días: repite el comando antes de que venzan (puedes programarlo con `cron`).

Los archivos `certs/*.pem` están en `.gitignore`: nunca subas llaves privadas a GitHub.

## 6. Enlace del repositorio en funcionamiento

1. Sube el proyecto a GitHub y copia la URL, por ejemplo `https://github.com/usuario/repositorio`.
2. Escríbela en `.env`: `REPO_URL=https://github.com/usuario/repositorio`.
3. Reinicia el servicio. La URL aparece en la tarjeta "Repositorio" de la sección de estado y en el pie de página.
4. Si el repositorio es privado, agrega al docente como colaborador (Settings → Collaborators) para que el enlace funcione para él.

## Puesta en marcha completa

```bash
cp .env.example .env
```

Edita `.env` y define como mínimo `SESSION_SECRET` (cadena larga y aleatoria), `DB_PASSWORD`, `DOMAIN` y `REPO_URL`. Luego:

```bash
./scripts/generar-certificado.sh localhost
docker compose up -d --build
docker compose ps
```

Abre `https://localhost` (o tu dominio). Comandos útiles:

```bash
docker compose logs -f balanceador
docker compose logs -f app1
docker compose restart app2
docker compose down
```

## Capturas sugeridas para el PDF

1. `docker compose ps` con los cinco servicios en estado `healthy` o `running`.
2. La sección "Estado del sistema" con todas las tarjetas en verde.
3. La prueba de balanceo con barras repartidas entre las tres instancias.
4. El candado HTTPS del navegador y el detalle del certificado.
5. `curl -sk https://tu-dominio/api/health` con la respuesta JSON.
6. La configuración DNS del dominio (registro A).
7. El repositorio en GitHub abierto desde el enlace de la página.
