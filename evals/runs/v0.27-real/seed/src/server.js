import { createServer } from 'node:http'
import { createOrder, listOrdersWithCustomers } from './orders.js'
import { previewTotal } from './cart.js'

function json(res, code, body) {
  res.writeHead(code, { 'content-type': 'application/json' })
  res.end(JSON.stringify(body))
}

async function readBody(req) {
  let raw = ''
  for await (const chunk of req) raw += chunk
  return raw ? JSON.parse(raw) : {}
}

export const server = createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/orders') return json(res, 200, await listOrdersWithCustomers())
    if (req.method === 'POST' && req.url === '/orders') return json(res, 201, await createOrder(await readBody(req)))
    if (req.method === 'POST' && req.url === '/cart/preview') return json(res, 200, { total: await previewTotal((await readBody(req)).items) })
    json(res, 404, { error: 'not found' })
  } catch (e) {
    json(res, 500, { error: String(e && e.message || e) })
  }
})

if (process.argv[1] && process.argv[1].endsWith('server.js')) {
  server.listen(process.env.PORT || 3000, () => console.log('orderdesk on :' + (process.env.PORT || 3000)))
}
