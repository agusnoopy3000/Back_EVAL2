// Prueba de humo (smoke test) sin dependencias externas.
// Levanta la app en un puerto efímero y valida los endpoints que no requieren BD.
const http = require('http');
const assert = require('assert');
const app = require('../server');

const server = app.listen(0, () => {
    const port = server.address().port;

    const get = (path) => new Promise((resolve, reject) => {
        http.get({ host: '127.0.0.1', port, path }, (res) => {
            let data = '';
            res.on('data', (c) => (data += c));
            res.on('end', () => resolve({ status: res.statusCode, body: data }));
        }).on('error', reject);
    });

    (async () => {
        const health = await get('/health');
        assert.strictEqual(health.status, 200, 'GET /health debe responder 200');
        assert.ok(JSON.parse(health.body).status === 'ok', '/health debe devolver status ok');

        const root = await get('/');
        assert.strictEqual(root.status, 200, 'GET / debe responder 200');
        assert.ok(JSON.parse(root.body).status === 'active', '/ debe devolver status active');

        console.log('✓ Smoke tests del backend OK');
        server.close(() => process.exit(0));
    })().catch((err) => {
        console.error('✗ Smoke tests fallidos:', err.message);
        server.close(() => process.exit(1));
    });
});
