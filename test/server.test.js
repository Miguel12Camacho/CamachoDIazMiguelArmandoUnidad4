const test = require("node:test");
const assert = require("node:assert/strict");
const { app, pool, validEmail, calculateShipping } = require("../server");

test("acepta correos con formato básico válido", () => {
  assert.equal(validEmail("alumno@example.com"), true);
});
test("rechaza correo sin arroba o dominio", () => {
  assert.equal(validEmail("alumnoexample.com"), false);
  assert.equal(validEmail("alumno@"), false);
});
test("rechaza entradas vacías y correos excesivamente largos", () => {
  assert.equal(validEmail(""), false);
  assert.equal(validEmail("x".repeat(250) + "@example.com"), false);
});
test("cobra envío en compras menores a 999", () => {
  assert.equal(calculateShipping(500), 79);
  assert.equal(calculateShipping(998.99), 79);
});
test("el envío es gratis desde 999", () => {
  assert.equal(calculateShipping(999), 0);
  assert.equal(calculateShipping(1647), 0);
});
test("el endpoint de salud informa la instancia y el estado", async () => {
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const response = await fetch(`http://127.0.0.1:${port}/api/health`);
    const body = await response.json();
    assert.ok(response.headers.get("x-served-by"));
    assert.equal(body.service, "tienda-digital");
    assert.ok(["ok", "degraded"].includes(body.status));
    assert.ok(body.instance);
    assert.ok(body.database);
  } finally {
    server.close();
    await pool.end().catch(() => undefined);
  }
});
