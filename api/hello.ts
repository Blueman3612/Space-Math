/**
 * ─────────────────────────────────────────────────────────────────
 * Calling your backend from your frontend:
 * ─────────────────────────────────────────────────────────────────
 *
 * In your game's frontend, use the Playcademy SDK client to call
 * your custom backend routes:
 *
 * ```typescript
 * import { PlaycademyClient } from 'playcademy'
 *
 * const client = PlaycademyClient.init()
 *
 * // GET request to /api/hello
 * const data = await client.backend.get('/hello')
 * console.log(data.message)
 *
 * // POST request to /api/hello
 * const result = await client.backend.post('/hello', { name: 'Player' })
 * console.log(result.received)
 *
 * // Other HTTP methods are also available:
 * await client.backend.put('/settings', settings)
 * await client.backend.patch('/profile', updates)
 * await client.backend.delete('/cache')
 *
 * // Custom methods
 * await client.backend.request('/custom', 'OPTIONS')
 * ```
 */

/**
 * Sample API route
 *
 * This route will be available at: https://<your-game-slug>.playcademy.gg/api/hello
 */
import type { Context } from 'hono'

/**
 * GET /api/hello
 */
export async function GET(c: Context): Promise<Response> {
    return c.json({
        message: 'Hello from your game backend!',
        timestamp: new Date().toISOString(),
    })
}

/**
 * POST /api/hello
 */
export async function POST(c: Context): Promise<Response> {
    const body = await c.req.json()

    return c.json({
        message: 'Received your data!',
        received: body,
    })
}

/**
 * Environment variables available via c.env:
 * - c.env.PLAYCADEMY_API_KEY - Game-scoped API key for calling Playcademy APIs
 * - c.env.GAME_ID - Your game's unique ID
 * - c.env.PLAYCADEMY_BASE_URL - Playcademy platform URL
 *
 * Access the SDK client:
 * - const sdk = c.get('sdk') - Pre-initialized PlaycademyClient
 */
